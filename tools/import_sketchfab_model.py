#!/usr/bin/env python3
"""Fetch a 3D model from Sketchfab, cut it down to a size this application can
draw, and record who made it.

Why this exists
---------------
RailSim draws its vehicles with a software renderer written in Dart: every
face is projected, depth-sorted and painted by hand, with no GPU behind it.
A model published for a game engine carries eighty thousand faces or more and
would stop the trainer dead. It is also authored in whatever axes and units
the modeller preferred, at whatever scale looked right, which is never the
scale of the vehicle record.

So a model cannot simply be dropped into `assets/models/`. It has to be
fetched under a licence that permits redistribution, reduced to a face count
the renderer can carry, converted to the Wavefront OBJ the Dart loader reads,
and listed in `assets/data/vehicle_models.json` with its author, its source
page and its terms. That last part is not paperwork: `VehicleModelAsset`
refuses to load a model whose attribution fields are empty, because shipping
somebody's work without their name on it is not something a missing string
should be allowed to cause.

Scale is deliberately NOT resolved here. The Dart loader fits the mesh to the
vehicle record's own width and reports the residual, so the figures the
trainer measures against stay the handbook's and the model stays a depiction.

Getting a token
---------------
The Sketchfab download endpoint needs one. Any free account has it at
https://sketchfab.com/settings/password, in the "API Token" field. Pass it as
--token or in SKETCHFAB_TOKEN.

    tools/import_sketchfab_model.py \
        --uid dfe130dfce724c30958cec51f2bd86b7 \
        --vehicle veh-t72 --target-faces 8000
"""

import argparse
import collections
import re
import io
import json
import os
import struct
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

import numpy as np

API = "https://api.sketchfab.com/v3"

# Licences whose terms allow this project to redistribute the file inside the
# application bundle. Anything else is refused rather than downloaded: the
# non-commercial and no-derivatives variants do not permit what shipping a
# model in a training application does to it.
REDISTRIBUTABLE = {
    "CC0 Public Domain": ("CC0 1.0", "https://creativecommons.org/publicdomain/zero/1.0/"),
    "CC Attribution": ("CC BY 4.0", "https://creativecommons.org/licenses/by/4.0/"),
    "CC Attribution-ShareAlike": ("CC BY-SA 4.0", "https://creativecommons.org/licenses/by-sa/4.0/"),
}

ROOT = Path(__file__).resolve().parent.parent


def _get(url, token=None):
    request = urllib.request.Request(url)
    if token:
        request.add_header("Authorization", f"Token {token}")
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read()


def model_info(uid, token):
    return json.loads(_get(f"{API}/models/{uid}", token))


def check_licence(info):
    """Refuses anything this project may not redistribute, and anything whose
    uploader plainly had no right to license it."""
    label = (info.get("license") or {}).get("label")
    if label not in REDISTRIBUTABLE:
        raise SystemExit(
            f"refusing: licence is {label!r}, which does not permit "
            f"redistribution in this bundle. Allowed: "
            f"{', '.join(sorted(REDISTRIBUTABLE))}"
        )
    if not info.get("isDownloadable"):
        raise SystemExit("refusing: the author has not made this model downloadable")

    # A CC tag on a model extracted from a commercial game is not a licence —
    # the uploader had nothing to grant. These get flagged for a human rather
    # than silently bundled into a ministry's training application.
    description = (info.get("description") or "").lower()
    for phrase in ("ripped from", "rip from", "extracted from", "datamined",
                   "war thunder", "world of tanks", "from squad", "armored warfare"):
        if phrase in description:
            raise SystemExit(
                f"refusing: the description says {phrase!r}, so this looks like "
                f"game-extracted geometry the uploader could not license. "
                f"Check by hand and pass --i-have-checked-provenance to override."
            )
    return REDISTRIBUTABLE[label]


def download_gltf(uid, token):
    """The download endpoint hands back short-lived links, one per format."""
    links = json.loads(_get(f"{API}/models/{uid}/download", token))
    entry = links.get("gltf") or links.get("glb")
    if not entry:
        raise SystemExit(f"no glTF download offered; formats were {list(links)}")
    return _get(entry["url"])


# --- glTF ------------------------------------------------------------------

_COMPONENT = {
    5120: np.int8, 5121: np.uint8, 5122: np.int16,
    5123: np.uint16, 5125: np.uint32, 5126: np.float32,
}
_COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


class Gltf:
    """Just enough glTF 2.0 to get triangles out. Materials, textures, skins
    and animation are all ignored: this renderer paints flat faces."""

    def __init__(self, gltf, buffers):
        self.g = gltf
        self.buffers = buffers

    @classmethod
    def open(cls, path):
        path = Path(path)
        data = path.read_bytes()
        if data[:4] == b"glTF":
            return cls._from_glb(data)
        gltf = json.loads(data)
        buffers = []
        for buffer in gltf.get("buffers", []):
            uri = buffer.get("uri")
            if uri is None:
                raise SystemExit("a .gltf with no buffer uri needs to be a .glb")
            if uri.startswith("data:"):
                import base64
                buffers.append(base64.b64decode(uri.split(",", 1)[1]))
            else:
                from urllib.parse import unquote
                buffers.append((path.parent / unquote(uri)).read_bytes())
        return cls(gltf, buffers)

    @classmethod
    def _from_glb(cls, data):
        _, _, total = struct.unpack_from("<III", data, 0)
        offset, gltf, binary = 12, None, b""
        while offset < total:
            length, kind = struct.unpack_from("<II", data, offset)
            chunk = data[offset + 8: offset + 8 + length]
            if kind == 0x4E4F534A:
                gltf = json.loads(chunk)
            elif kind == 0x004E4942:
                binary = chunk
            offset += 8 + length + (-length % 4)
        return cls(gltf, [binary])

    def accessor(self, index):
        acc = self.g["accessors"][index]
        count, per = acc["count"], _COUNT[acc["type"]]
        dtype = _COMPONENT[acc["componentType"]]
        if "bufferView" not in acc:
            return np.zeros((count, per), dtype=dtype)
        view = self.g["bufferViews"][acc["bufferView"]]
        buffer = self.buffers[view.get("buffer", 0)]
        base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        stride = view.get("byteStride")
        width = np.dtype(dtype).itemsize * per
        if stride and stride != width:
            # Interleaved: take the element out of each stride slot.
            raw = np.frombuffer(buffer, np.uint8, count=stride * (count - 1) + width,
                                offset=base)
            rows = np.lib.stride_tricks.as_strided(
                raw, shape=(count, width), strides=(stride, 1))
            out = np.ascontiguousarray(rows).view(dtype).reshape(count, per)
        else:
            out = np.frombuffer(buffer, dtype, count=count * per,
                                offset=base).reshape(count, per)
        return np.array(out)

    def triangles(self):
        """Every triangle in the file's default scene, in scene coordinates."""
        vertices, faces = [], []
        base = 0

        def node_matrix(node):
            if "matrix" in node:
                # glTF stores column-major.
                return np.array(node["matrix"], np.float64).reshape(4, 4).T
            matrix = np.eye(4)
            if "scale" in node:
                matrix = np.diag(list(node["scale"]) + [1.0]) @ matrix
            if "rotation" in node:
                x, y, z, w = node["rotation"]
                rotation = np.array([
                    [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w), 0],
                    [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w), 0],
                    [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y), 0],
                    [0, 0, 0, 1]])
                matrix = rotation @ matrix
            if "translation" in node:
                translation = np.eye(4)
                translation[:3, 3] = node["translation"]
                matrix = translation @ matrix
            return matrix

        def walk(index, parent):
            nonlocal base
            node = self.g["nodes"][index]
            world = parent @ node_matrix(node)
            if "mesh" in node:
                for primitive in self.g["meshes"][node["mesh"]].get("primitives", []):
                    if primitive.get("mode", 4) != 4:
                        continue
                    position = primitive.get("attributes", {}).get("POSITION")
                    if position is None:
                        continue
                    points = self.accessor(position).astype(np.float64)
                    points = (world[:3, :3] @ points.T).T + world[:3, 3]
                    if "indices" in primitive:
                        index_data = self.accessor(primitive["indices"]).reshape(-1)
                    else:
                        index_data = np.arange(len(points))
                    triangles = index_data[: len(index_data) // 3 * 3].reshape(-1, 3)
                    vertices.append(points)
                    faces.append(triangles.astype(np.int64) + base)
                    base += len(points)
            for child in node.get("children", []):
                walk(child, world)

        scene = self.g.get("scene", 0)
        roots = self.g["scenes"][scene].get("nodes", []) if self.g.get("scenes") else []
        for root in roots:
            walk(root, np.eye(4))
        if not vertices:
            raise SystemExit("no triangles found in the file")
        return np.vstack(vertices), np.vstack(faces)


# --- Wavefront OBJ input ---------------------------------------------------

# A model is authored in the modeller's own language, and this project's Dart
# loader picks a surface colour by looking for English words in the material
# name. These are the part names that actually turn up on Soviet-armour models
# published from Chinese and Russian modelling communities, mapped to the words
# `ObjMeshLoader.materialFromName` reads. A name not in the table is passed
# through unchanged and lands on the hull, which is the right default: getting
# it wrong tints one panel and changes no measurement.
MATERIAL_WORDS = {
    "履带": "track", "轮子": "wheel", "负重轮": "roadwheel", "主动轮": "sprocket",
    "诱导轮": "idler", "炮管": "gun barrel", "炮塔": "turret",
    "炮塔外部": "turret exterior", "机枪": "machine gun", "车身": "hull",
    "车身左侧": "hull left", "车身右侧": "hull right", "车身底部": "hull bottom",
    "车顶": "hull roof", "车尾": "hull rear", "车灯": "hull lamp",
    "螺丝": "hull bolt", "扣子": "hull clasp", "挡泥板": "fender",
    "裙板": "skirt", "油桶": "drum", "箱子": "stowage box",
    "гусеница": "track", "башня": "turret", "корпус": "hull",
    "колесо": "wheel", "ствол": "gun barrel",
}


def translate_material(name):
    if name in MATERIAL_WORDS:
        return MATERIAL_WORDS[name]
    for source, english in MATERIAL_WORDS.items():
        if source in name:
            return english
    return name


def read_obj(path):
    """Vertices, triangles, a material name per triangle, and the file's own
    corner normals when it has them.

    Polygons are fanned into triangles: the exported file here is 76% quads and
    n-gons, and everything downstream — the quadric planes, the renderer —
    works on triangles only.

    The normals are worth carrying rather than recomputing. A modeller's
    smoothing groups say which edges are meant to be hard and which are meant
    to disappear, and on a cast turret with real surface relief that judgement
    is the difference between a shape and a rough patch. Anything this tool
    works out from the geometry alone is a guess at what they already decided.
    """
    vertices = []
    normals = []
    faces = []
    face_normals = []
    face_material = []
    current = "default"
    with open(path, "r", errors="replace") as handle:
        for line in handle:
            if line.startswith("v "):
                vertices.append([float(x) for x in line.split()[1:4]])
            elif line.startswith("vn "):
                normals.append([float(x) for x in line.split()[1:4]])
            elif line.startswith("usemtl "):
                current = line[7:].strip() or "default"
            elif line.startswith("f "):
                corners = []
                corner_normals = []
                for token in line.split()[1:]:
                    bits = token.split("/")
                    index = int(bits[0])
                    corners.append(index - 1 if index > 0 else len(vertices) + index)
                    if len(bits) > 2 and bits[2]:
                        n = int(bits[2])
                        corner_normals.append(n - 1 if n > 0 else len(normals) + n)
                    else:
                        corner_normals.append(-1)
                for k in range(1, len(corners) - 1):
                    faces.append([corners[0], corners[k], corners[k + 1]])
                    face_normals.append(
                        [corner_normals[0], corner_normals[k], corner_normals[k + 1]])
                    face_material.append(current)
    names = sorted(set(face_material))
    lookup = {name: i for i, name in enumerate(names)}
    corner = np.array(face_normals, np.int64)
    authored = None
    if len(normals) and corner.size and (corner >= 0).all():
        authored = np.array(normals, np.float64)[corner]      # (F, 3, 3)
    return (np.array(vertices, np.float64),
            np.array(faces, np.int64),
            np.array([lookup[m] for m in face_material], np.int32),
            names,
            authored)


# --- reduction -------------------------------------------------------------

def weld(vertices, faces, materials=None, tolerance=1e-6):
    """Merges vertices a modeller split for texturing. A glTF splits a vertex
    wherever the UV or normal differs, which triples the count and leaves the
    surface non-manifold for any algorithm that walks edges."""
    keys = np.round(vertices / tolerance).astype(np.int64)
    _, first, inverse = np.unique(keys, axis=0, return_index=True, return_inverse=True)
    welded = vertices[first]
    remapped = inverse[faces]
    keep = ((remapped[:, 0] != remapped[:, 1]) &
            (remapped[:, 1] != remapped[:, 2]) &
            (remapped[:, 0] != remapped[:, 2]))
    return (welded, remapped[keep],
            (None if materials is None else materials[keep]), keep)


def decimate(vertices, faces, target, materials=None):
    """Quadric error decimation (Garland & Heckbert).

    Each vertex carries the summed squared distance to the planes of the faces
    around it; an edge is collapsed to the point minimising that sum, cheapest
    edge first. It keeps silhouettes and flat panels — a tank's hull sides,
    its glacis, the run of its track — where a cheaper grid-clustering
    reduction would round the corners off and crack the surface.
    """
    import heapq

    vertices = vertices.copy()
    faces = faces.copy()
    count = len(vertices)

    # One 4x4 quadric per vertex, summed from the planes of its faces.
    quadrics = np.zeros((count, 4, 4))
    p0, p1, p2 = (vertices[faces[:, 0]], vertices[faces[:, 1]], vertices[faces[:, 2]])
    normals = np.cross(p1 - p0, p2 - p0)
    lengths = np.linalg.norm(normals, axis=1)
    area = lengths / 2.0
    ok = lengths > 1e-12
    normals[ok] /= lengths[ok][:, None]
    planes = np.hstack([normals, -np.einsum("ij,ij->i", normals, p0)[:, None]])
    weighted = planes * np.sqrt(np.maximum(area, 1e-12))[:, None]
    outer = np.einsum("ij,ik->ijk", weighted, weighted)
    for corner in range(3):
        np.add.at(quadrics, faces[:, corner], outer)

    alive_face = np.ones(len(faces), bool)
    alive_vertex = np.ones(count, bool)
    around = [set() for _ in range(count)]
    for index, face in enumerate(faces):
        for corner in face:
            around[corner].add(index)

    def cost_of(i, j):
        Q = quadrics[i] + quadrics[j]
        A = Q[:3, :3].copy()
        A[np.diag_indices(3)] += 1e-12
        try:
            point = np.linalg.solve(A, -Q[:3, 3])
        except np.linalg.LinAlgError:
            point = (vertices[i] + vertices[j]) / 2.0
        if not np.all(np.isfinite(point)):
            point = (vertices[i] + vertices[j]) / 2.0
        homogeneous = np.append(point, 1.0)
        return float(homogeneous @ Q @ homogeneous), point

    version = np.zeros(count, np.int64)
    heap = []
    seen = set()
    for face in faces:
        for a, b in ((0, 1), (1, 2), (2, 0)):
            i, j = int(face[a]), int(face[b])
            edge = (i, j) if i < j else (j, i)
            if edge in seen:
                continue
            seen.add(edge)
            error, point = cost_of(*edge)
            heapq.heappush(heap, (error, edge[0], edge[1], 0, 0, point))

    live = int(alive_face.sum())
    while live > target and heap:
        error, i, j, vi, vj, point = heapq.heappop(heap)
        if not (alive_vertex[i] and alive_vertex[j]):
            continue
        if vi != version[i] or vj != version[j]:
            continue

        shared = around[i] & around[j]
        merged = around[i] | around[j]
        vertices[i] = point
        quadrics[i] = quadrics[i] + quadrics[j]
        alive_vertex[j] = False

        for index in merged:
            if not alive_face[index]:
                continue
            face = faces[index]
            face[face == j] = i
            if face[0] == face[1] or face[1] == face[2] or face[0] == face[2]:
                alive_face[index] = False
                live -= 1
        around[i] = {f for f in merged if alive_face[f]}
        around[j] = set()
        version[i] += 1

        neighbours = set()
        for index in around[i]:
            neighbours.update(int(c) for c in faces[index])
        neighbours.discard(i)
        for other in neighbours:
            if not alive_vertex[other]:
                continue
            edge = (i, other) if i < other else (other, i)
            new_error, new_point = cost_of(*edge)
            heapq.heappush(heap, (new_error, edge[0], edge[1],
                                  version[edge[0]], version[edge[1]], new_point))

    kept_materials = None if materials is None else materials[alive_face]
    faces = faces[alive_face]
    used, remapped = np.unique(faces, return_inverse=True)
    return vertices[used], remapped.reshape(-1, 3), kept_materials



def smooth_normals(vertices, faces, crease_degrees=50.0):
    """A normal per face corner, smooth across a curve and sharp across an edge.

    Why this matters more than it sounds: the renderer shades a triangle from
    its own plane unless it is told otherwise, and a cast turret modelled with
    real surface relief is thousands of tiny planes at slightly different
    angles. Flat-shaded, that reads as speckle — the shape disappears into
    noise. Averaging the surrounding face normals at each vertex is what makes
    a curve read as a curve.

    Averaging everywhere would be wrong too: it would round off the glacis
    join and the edge of every hatch, and the vehicle would look melted. So a
    corner whose own face turns more than `crease_degrees` away from the
    average keeps its face normal, which leaves hard edges hard. That is the
    cheap, vectorised stand-in for splitting the vertex, and at this face count
    it is indistinguishable.

    Area-weighted, because the cross product's length is twice the triangle's
    area: a large face should pull the average further than a sliver.
    """
    v0 = vertices[faces[:, 0]]
    v1 = vertices[faces[:, 1]]
    v2 = vertices[faces[:, 2]]
    weighted = np.cross(v1 - v0, v2 - v0)
    lengths = np.linalg.norm(weighted, axis=1, keepdims=True)
    face_unit = weighted / np.where(lengths == 0, 1.0, lengths)

    summed = np.zeros_like(vertices)
    for k in range(3):
        np.add.at(summed, faces[:, k], weighted)
    lengths = np.linalg.norm(summed, axis=1, keepdims=True)
    vertex_unit = summed / np.where(lengths == 0, 1.0, lengths)

    corners = vertex_unit[faces].copy()                      # (F, 3, 3)
    agreement = np.einsum("fij,fj->fi", corners, face_unit)
    sharp = agreement < np.cos(np.radians(crease_degrees))
    corners[sharp] = np.broadcast_to(face_unit[:, None, :], corners.shape)[sharp]

    # A corner that cancelled out entirely falls back to its own face.
    dead = np.linalg.norm(corners, axis=2) == 0
    corners[dead] = np.broadcast_to(face_unit[:, None, :], corners.shape)[dead]
    return corners


def obj_text(vertices, faces, header, materials=None, names=None, normals=None):
    """Faces grouped by material, so the Dart loader can colour the tracks
    differently from the hull. Vertices and normals only — the renderer paints
    flat faces and reads no texture.

    Returned as text rather than written straight out, because the same bytes
    go either to a file under `assets/` or into a Dart source constant,
    depending on what the model's licence permits. See --emit.
    """
    out = []
    for line in header:
        out.append(f"# {line}\n")
    for x, y, z in vertices:
        out.append(f"v {x:.5f} {y:.5f} {z:.5f}\n")

    # Corner normals, shared wherever they round to the same direction. Four
    # decimals is finer than a byte of shading can show and collapses the
    # roughly 1.6 million corners of a full-detail import to a fraction of
    # that, which is the difference between a readable file and a huge one.
    corner_normal = None
    if normals is not None:
        keys = np.round(normals.reshape(-1, 3), 4)
        unique, inverse = np.unique(keys, axis=0, return_inverse=True)
        for x, y, z in unique:
            out.append(f"vn {x:.4f} {y:.4f} {z:.4f}\n")
        corner_normal = inverse.reshape(-1, 3) + 1

    def face_line(index):
        a, b, c = faces[index] + 1
        if corner_normal is None:
            return f"f {a} {b} {c}\n"
        na, nb, nc = corner_normal[index]
        return f"f {a}//{na} {b}//{nb} {c}//{nc}\n"

    if materials is None or names is None:
        for index in range(len(faces)):
            out.append(face_line(index))
        return "".join(out)

    order = np.argsort(materials, kind="stable")
    current = None
    for index in order:
        name = translate_material(names[materials[index]])
        if name != current:
            out.append(f"usemtl {name}\n")
            current = name
        out.append(face_line(index))
    return "".join(out)


def write_obj(path, vertices, faces, header, materials=None, names=None):
    """The asset-file form of [obj_text]."""
    path.write_text(obj_text(vertices, faces, header, materials, names))


# --- compiled-in output ----------------------------------------------------

def write_dart(path, obj_text, vehicle_id, info, licence, notes):
    """Emits the mesh as Dart source rather than as a file under `assets/`.

    Not an aesthetic choice — a licence one. A model bought under CGTrader's
    Royalty Free License may be shipped inside an application only as an
    "Incorporated Product", defined in their terms as one that "cannot be
    extracted from an application ... and used as a stand-alone object without
    the use of reverse engineering tools or techniques" (§21A.6 and definition
    8). A Wavefront file sitting in `assets/models/` fails that plainly: on a
    Linux desktop build it lands in `data/flutter_assets/` as readable text
    that anyone can copy out with a file manager.

    Compiled into the Dart snapshot it does not. The geometry is gzipped and
    base64'd into a source constant, so it ends up inside the AOT binary, and
    the existing OBJ parser reads it back unchanged.

    Models under a licence that DOES permit redistribution — the Creative
    Commons ones this tool otherwise fetches — do not need this and stay as
    ordinary assets, where they are easier to inspect and replace.
    """
    import base64
    import gzip
    packed = base64.b64encode(gzip.compress(obj_text.encode(), 9)).decode()
    lines = [packed[i:i + 96] for i in range(0, len(packed), 96)]
    body = "\n".join(f"    '{line}'" for line in lines)
    identifier = re.sub(r"[^a-z0-9]+", "_", vehicle_id.lower()).strip("_")
    path.write_text(f"""// GENERATED by tools/import_sketchfab_model.py — do not edit by hand.
//
// {info['name']} by {info['user']['displayName']}
// {info['viewerUrl']}
// {licence[0]}{(' — ' + licence[1]) if licence[1] else ''}
//
// {notes}
//
// The geometry is held here, in source, rather than as a file under assets/
// because this model's licence permits shipping it inside an application only
// where it cannot be extracted and used on its own. See write_dart() in the
// import tool for the clause and the reasoning.
import 'compiled_vehicle_model.dart';

const CompiledVehicleModel {identifier}Model = CompiledVehicleModel(
  vehicleId: '{vehicle_id}',
  fileName: '{vehicle_id}.obj',
  sourceTitle: {dart_string(info['name'])},
  sourceUrl: {dart_string(info['viewerUrl'])},
  license: {dart_string(licence[0])},
  licenseUrl: {dart_string(licence[1])},
  author: {dart_string(info['user']['displayName'])},
  notes: {dart_string(notes)},
  packedObj: <String>[
{body}
  ],
);
""")


def dart_string(value):
    escaped = str(value).replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")
    escaped = escaped.replace("\n", " ")
    return f"'{escaped}'"


def update_manifest(vehicle_id, file_name, info, licence, notes):
    path = ROOT / "assets" / "data" / "vehicle_models.json"
    manifest = json.loads(path.read_text())
    name, url = licence
    entry = {
        "vehicleId": vehicle_id,
        "file": f"models/{file_name}",
        "sourceTitle": info["name"],
        "sourceUrl": info["viewerUrl"],
        "license": name,
        "licenseUrl": url,
        "author": info["user"]["displayName"],
        "axisConvention": "yUpFacingMinusZ",
        "notes": notes,
    }
    models = [m for m in manifest["models"] if m.get("vehicleId") != vehicle_id]
    models.append(entry)
    manifest["models"] = models
    path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    return entry


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--uid", help="Sketchfab model uid, when it is from there")
    # For a model from anywhere else, or one downloaded by hand: the credit is
    # given explicitly instead of being looked up. There is no third option —
    # `VehicleModelAsset` refuses to load a model whose author, source or
    # licence is blank, so a file cannot reach the bundle uncredited.
    parser.add_argument("--source-title")
    parser.add_argument("--source-url")
    parser.add_argument("--author")
    parser.add_argument("--license", help="e.g. 'CC BY 4.0'")
    parser.add_argument("--license-url")
    parser.add_argument("--vehicle", required=True, help="e.g. veh-t72")
    parser.add_argument("--target-faces", type=int, default=8000)
    parser.add_argument("--token", default=os.environ.get("SKETCHFAB_TOKEN"))
    parser.add_argument("--i-have-checked-provenance", action="store_true")
    parser.add_argument("--archive", help="a .zip already downloaded, instead of fetching")
    parser.add_argument("--notes", default=None)
    parser.add_argument(
        "--emit", choices=("asset", "dart"), default="asset",
        help="'asset' writes assets/models/<vehicle>.obj and lists it in "
             "vehicle_models.json — right for a licence that permits "
             "redistribution. 'dart' compiles the geometry into "
             "lib/domain/usecases/generated/ and touches neither, which is "
             "what a licence forbidding extraction requires. See write_dart().")
    args = parser.parse_args()

    manual = any([args.source_title, args.source_url, args.author, args.license])
    if manual:
        missing = [name for name, value in (
            ("--source-title", args.source_title),
            ("--source-url", args.source_url),
            ("--author", args.author),
            ("--license", args.license)) if not value]
        if missing:
            raise SystemExit(
                "an explicitly credited import needs all of them: missing "
                + ", ".join(missing))
        if not args.archive:
            raise SystemExit("--archive is required for an explicit credit")
        info = {
            "name": args.source_title,
            "viewerUrl": args.source_url,
            "user": {"displayName": args.author},
            "faceCount": None,
        }
        licence = (args.license, args.license_url or "")
    else:
        if not args.uid:
            raise SystemExit("pass --uid, or credit the model explicitly with "
                             "--source-title/--source-url/--author/--license")
        if not args.token and not args.archive:
            raise SystemExit(
                "no token. Sign in at sketchfab.com, copy the API Token from\n"
                "https://sketchfab.com/settings/password, and pass --token or set\n"
                "SKETCHFAB_TOKEN."
            )
        info = model_info(args.uid, args.token)
        if args.i_have_checked_provenance:
            licence = REDISTRIBUTABLE.get((info.get("license") or {}).get("label"))
            if licence is None:
                raise SystemExit("licence still not redistributable; not overridable")
        else:
            licence = check_licence(info)

    print(f"{info['name']} — {info['user']['displayName']} "
          f"({licence[0]}), {info.get('faceCount') or 'unknown'} faces as published")

    with tempfile.TemporaryDirectory() as workspace:
        if args.archive:
            data = Path(args.archive).read_bytes()
        else:
            print("downloading…")
            data = download_gltf(args.uid, args.token)
        if args.archive and not zipfile.is_zipfile(args.archive):
            # A bare .obj or .glb handed over directly.
            target = Path(workspace) / Path(args.archive).name
            target.write_bytes(data)
        else:
            zipfile.ZipFile(io.BytesIO(data)).extractall(workspace)
        candidates = [c for c in sorted(Path(workspace).rglob("*"))
                      if c.suffix.lower() in (".gltf", ".glb", ".obj")]
        if not candidates:
            raise SystemExit("no .gltf, .glb or .obj inside the archive")
        # Prefer glTF, which carries its own scene transforms; fall back to the
        # Wavefront export, which is what several publishers hand out instead.
        candidates.sort(key=lambda c: c.suffix.lower() != ".obj")
        chosen = candidates[0]
        print(f"reading {chosen.name}")
        if chosen.suffix.lower() == ".obj":
            vertices, faces, materials, names, authored = read_obj(chosen)
        else:
            vertices, faces = Gltf.open(chosen).triangles()
            materials, names, authored = None, None, None

    print(f"  {len(vertices)} vertices, {len(faces)} triangles as published")
    before = len(faces)
    vertices, faces, materials, kept = weld(vertices, faces, materials)
    print(f"  {len(vertices)} vertices, {len(faces)} triangles welded")
    if authored is not None and before == len(kept):
        authored = authored[kept]
    if len(faces) > args.target_faces:
        vertices, faces, materials = decimate(
            vertices, faces, args.target_faces, materials)
        print(f"  {len(vertices)} vertices, {len(faces)} triangles after reduction")
        # Decimation moves and merges vertices, so the file's normals no
        # longer describe the surface that is left.
        authored = None
    if names is not None:
        kept = collections.Counter(names[m] for m in materials)
        print("  surfaces kept: " + ", ".join(
            f"{translate_material(n)}={c}" for n, c in kept.most_common(6)))

    size = vertices.max(axis=0) - vertices.min(axis=0)
    print(f"  bounding box {size[0]:.2f} x {size[1]:.2f} x {size[2]:.2f} "
          f"(file units; the Dart loader scales this to the record)")

    file_name = f"{args.vehicle}.obj"
    notes = args.notes or (
        f"Reduced from {info.get('faceCount') or 'the published mesh'} faces to "
        f"{len(faces)} by quadric error decimation, so that RailSim's software "
        f"renderer can draw it. Imported with tools/import_sketchfab_model.py."
    )
    if authored is not None:
        print(f"  keeping the file's own {len(np.unique(authored.reshape(-1, 3), axis=0))} "
              f"corner normals — the modeller's smoothing, not a guess at it")
        normals = authored
    else:
        print("  computing corner normals for smooth shading…")
        normals = smooth_normals(vertices, faces)

    text = obj_text(
        vertices, faces,
        [f"{info['name']} by {info['user']['displayName']}",
         f"{info['viewerUrl']}",
         f"{licence[0]} — {licence[1]}",
         notes],
        materials, names, normals,
    )

    if args.emit == "dart":
        identifier = re.sub(r"[^a-z0-9]+", "_", args.vehicle.lower()).strip("_")
        out = (ROOT / "lib" / "domain" / "usecases" / "generated"
               / f"{identifier}_model.g.dart")
        write_dart(out, text, args.vehicle, info, licence, notes)
        print(f"\nwrote {out.relative_to(ROOT)} ({len(text) / 1e6:.2f} MB of "
              f"Wavefront, gzipped and base64'd into source)")
        print("assets/models/ and vehicle_models.json were left alone: this "
              "licence does not permit the model to ship as an extractable "
              "file. Check it is listed in CompiledVehicleModels.byVehicleId.")
        return

    write_obj(ROOT / "assets" / "models" / file_name, vertices, faces,
              [f"{info['name']} by {info['user']['displayName']}",
               f"{info['viewerUrl']}",
               f"{licence[0]} — {licence[1]}",
               notes],
              materials, names)
    entry = update_manifest(args.vehicle, file_name, info, licence, notes)
    print(f"\nwrote assets/models/{file_name}")
    print(f"listed in vehicle_models.json as {entry['sourceTitle']} — "
          f"{entry['author']} ({entry['license']})")


if __name__ == "__main__":
    main()
