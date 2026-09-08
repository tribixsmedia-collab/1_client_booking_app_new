// Encodes a file of "lat,lng" lines with the app's own implementation, so the
// output can be diffed against the backend's for the same points.
//
// Not part of the app or its tests: it exists because the two ports of Open
// Location Code have to agree character for character, and agreeing on
// Google's published vectors alone would not prove they agree everywhere.
//
//   dart run tool/cross_check_plus_codes.dart <points.txt> <out.txt>
import 'dart:io';

import 'package:customer_app/utils/plus_code.dart';

void main(List<String> args) {
  final lines = File(args[0]).readAsLinesSync();
  final lengths = [4, 6, 8, 10, 11, 13, 15];
  final out = StringBuffer();

  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final parts = line.split(',');
    final latitude = double.parse(parts[0]);
    final longitude = double.parse(parts[1]);
    out.writeln(lengths
        .map((n) => encodePlusCode(latitude, longitude, codeLength: n))
        .join('|'));
  }

  File(args[1]).writeAsStringSync(out.toString());
  stdout.writeln('dart wrote ${lines.length} rows');
}
