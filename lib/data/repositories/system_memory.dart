import 'dart:io';

/// How much memory the machine has, in megabytes, or null when it cannot be
/// read.
///
/// Used once, to decide whether the program should default to leaving the
/// imported three-dimensional models on disk. A T-72's mesh is 548,889
/// triangles and its working arrays come to about 126 MB on top of the 665 MB
/// the program already holds; on a 2 GB machine, where Windows itself wants
/// most of a gigabyte, that is the difference between running and swapping.
///
/// Null is a normal answer, not a failure: it means "do not guess", and the
/// setting is left to the instructor.
Future<int?> totalSystemMemoryMb() async {
  try {
    if (Platform.isLinux) {
      // MemTotal is the first line of /proc/meminfo, in kB.
      final line = await File('/proc/meminfo')
          .openRead()
          .transform(const SystemEncoding().decoder)
          .join();
      final match = RegExp(r'MemTotal:\s+(\d+)\s+kB').firstMatch(line);
      if (match != null) return int.parse(match.group(1)!) ~/ 1024;
      return null;
    }
    if (Platform.isWindows) {
      // No API for this without a plugin, so ask Windows for it. CIM rather
      // than the deprecated wmic, which is absent from recent builds.
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        '(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory',
      ]);
      final bytes = int.tryParse(result.stdout.toString().trim());
      return bytes == null ? null : bytes ~/ (1024 * 1024);
    }
  } catch (_) {
    // Any failure means "cannot tell", which is a legitimate answer here.
  }
  return null;
}

/// Below this, the imported models are left off by default.
///
/// 3 GB rather than 2: a machine with exactly 2 GB has roughly a gigabyte left
/// after Windows, and the program needs about 790 MB with one tank's mesh
/// loaded. The margin above that is small enough that 3 GB is the honest line.
const int kLowMemoryThresholdMb = 3072;
