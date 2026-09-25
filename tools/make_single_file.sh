#!/usr/bin/env bash
# Packs the Linux release bundle into ONE double-clickable file.
#
# Flutter's Linux output is a directory — an executable beside its .so files and
# its assets — which is awkward to hand to somebody. This wraps the whole
# directory in a self-extracting shell archive: one file, chmod +x, runs the
# program. The Linux answer to "make it an exe".
#
# It is NOT a Windows .exe. Flutter cannot cross-compile to Windows from Linux
# (`flutter build` here offers apk, linux and web only, and there is no MSVC or
# mingw toolchain on this machine). For the .exe, run `flutter build windows`
# on a Windows machine — the windows/ scaffold is already in this project.
set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE=build/linux/x64/release/bundle
OUT=dist/RailSim-linux-x86_64.run
[ -d "$BUNDLE" ] || { echo "build first: flutter build linux --release" >&2; exit 1; }

PAYLOAD=$(mktemp); trap 'rm -f "$PAYLOAD"' EXIT
tar czf "$PAYLOAD" -C "$BUNDLE" .

mkdir -p dist
cat > "$OUT" <<'HEADER'
#!/usr/bin/env bash
# RailSim — self-extracting. Runs from a temporary directory.
set -euo pipefail
DIR=$(mktemp -d /tmp/railsim-XXXXXX)
trap 'rm -rf "$DIR"' EXIT
ARCHIVE_LINE=$(awk '/^__PAYLOAD__$/ {print NR + 1; exit 0; }' "$0")
tail -n +"$ARCHIVE_LINE" "$0" | tar xz -C "$DIR"
exec "$DIR/railsim" "$@"
__PAYLOAD__
HEADER
cat "$PAYLOAD" >> "$OUT"
chmod +x "$OUT"
echo "wrote $OUT ($(du -h "$OUT" | cut -f1))"
