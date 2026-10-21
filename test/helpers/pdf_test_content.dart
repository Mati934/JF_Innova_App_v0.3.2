import 'dart:convert';
import 'dart:io';

/// Inspect generated PDF streams without a platform plugin or extra dependency.
List<String> pdfStreams(List<int> bytes) {
  final source = latin1.decode(bytes);
  return RegExp(
    r'stream\r?\n(.*?)\r?\nendstream',
    dotAll: true,
  ).allMatches(source).map((match) {
    final raw = latin1.encode(match.group(1)!);
    try {
      return latin1.decode(zlib.decode(raw));
    } catch (_) {
      return latin1.decode(raw);
    }
  }).toList();
}

String pdfText(List<int> bytes) {
  final streams = pdfStreams(bytes);
  final result = StringBuffer();
  for (final cmap in streams.where(
    (stream) => stream.contains('beginbfchar'),
  )) {
    final glyphs = <int, int>{};
    for (final match in RegExp(
      r'<([0-9A-F]{4})>\s*<([0-9A-F]{4})>',
    ).allMatches(cmap)) {
      glyphs[int.parse(match.group(1)!, radix: 16)] = int.parse(
        match.group(2)!,
        radix: 16,
      );
    }
    for (final stream in streams.where((stream) => stream.contains(']TJ'))) {
      for (final match in RegExp(r'<([0-9a-fA-F]+)>').allMatches(stream)) {
        final hex = match.group(1)!;
        for (var index = 0; index + 4 <= hex.length; index += 4) {
          result.writeCharCode(
            glyphs[int.parse(hex.substring(index, index + 4), radix: 16)] ?? 32,
          );
        }
        result.write(' ');
      }
    }
    result.writeln();
  }
  return result.toString().replaceAll(RegExp(r'\s+'), ' ');
}

int pdfPageCount(List<int> bytes) => RegExp(r'/Count\s+(\d+)')
    .allMatches(latin1.decode(bytes))
    .map((match) => int.parse(match.group(1)!))
    .reduce((a, b) => a > b ? a : b);

int pdfImageDrawCount(List<int> bytes) => pdfStreams(bytes)
    .map((stream) => RegExp(r'/\w+\s+Do\b').allMatches(stream).length)
    .fold(0, (total, count) => total + count);
