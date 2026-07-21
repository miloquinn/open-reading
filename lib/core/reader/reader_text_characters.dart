/// Character rules shared by TXT chapter splitting and flowing-text layout.
///
/// Flutter treats these Unicode controls as hard line breaks, so the reader
/// must recognize the same set when deciding where a paragraph starts.
bool isReaderLineBreakCodeUnit(int codeUnit) =>
    codeUnit == 0x000A || // LF
    codeUnit == 0x000B || // vertical tab
    codeUnit == 0x000C || // form feed
    codeUnit == 0x000D || // CR
    codeUnit == 0x0085 || // next line
    codeUnit == 0x2028 || // line separator
    codeUnit == 0x2029; // paragraph separator

int readerLineBreakLengthAt(String text, int offset) {
  if (offset < 0 || offset >= text.length) return 0;
  if (text.codeUnitAt(offset) == 0x000D &&
      offset + 1 < text.length &&
      text.codeUnitAt(offset + 1) == 0x000A) {
    return 2;
  }
  return isReaderLineBreakCodeUnit(text.codeUnitAt(offset)) ? 1 : 0;
}

List<String> splitReaderTextLines(String text) {
  final lines = <String>[];
  var lineStart = 0;
  var offset = 0;
  while (offset < text.length) {
    final breakLength = readerLineBreakLengthAt(text, offset);
    if (breakLength == 0) {
      offset++;
      continue;
    }
    lines.add(text.substring(lineStart, offset));
    offset += breakLength;
    lineStart = offset;
  }
  lines.add(text.substring(lineStart));
  return lines;
}

/// Whitespace that can appear before the first visible character of a TXT
/// paragraph. These are display-only source characters and are replaced by
/// the configured reader indent.
bool isReaderIndentCodeUnit(int codeUnit) =>
    codeUnit == 0x0009 || // tab
    codeUnit == 0x0020 || // space
    codeUnit == 0x00A0 || // no-break space
    codeUnit == 0x1680 || // ogham space mark
    codeUnit == 0x180E || // mongolian vowel separator (legacy whitespace)
    (codeUnit >= 0x2000 && codeUnit <= 0x200A) ||
    codeUnit == 0x200B || // zero-width space
    codeUnit == 0x202F || // narrow no-break space
    codeUnit == 0x205F || // mathematical space
    codeUnit == 0x3000 || // ideographic space
    codeUnit == 0xFEFF; // BOM / zero-width no-break space
