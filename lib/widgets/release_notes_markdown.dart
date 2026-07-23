import 'package:flutter/material.dart';

typedef ReleaseNotesLinkCallback = Future<void> Function(Uri uri);

/// A small, dependency-free Markdown renderer for release notes.
///
/// It intentionally supports the formatting commonly used by GitHub release
/// bodies: headings, paragraphs, unordered and ordered lists, block quotes,
/// fenced code blocks, rules, emphasis, inline code, strike-through and links.
class ReleaseNotesMarkdown extends StatelessWidget {
  const ReleaseNotesMarkdown({super.key, required this.data, this.onTapLink});

  final String data;
  final ReleaseNotesLinkCallback? onTapLink;

  @override
  Widget build(BuildContext context) {
    final blocks = _MarkdownBlock.parse(data);
    return SelectionArea(
      child: Column(
        key: const ValueKey('release-notes-markdown'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, block) in blocks.indexed)
            _ReleaseNotesBlock(
              key: ValueKey('release-notes-block-$index'),
              block: block,
              onTapLink: onTapLink,
            ),
        ],
      ),
    );
  }
}

class _ReleaseNotesBlock extends StatelessWidget {
  const _ReleaseNotesBlock({
    super.key,
    required this.block,
    required this.onTapLink,
  });

  final _MarkdownBlock block;
  final ReleaseNotesLinkCallback? onTapLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      height: 1.55,
    );

    final child = switch (block.type) {
      _MarkdownBlockType.heading => Text.rich(
        TextSpan(
          children: _inlineSpans(
            context,
            block.text,
            onTapLink: onTapLink,
            baseStyle: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurface,
              fontSize: switch (block.level) {
                1 => 20,
                2 => 17,
                _ => 15,
              },
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
        ),
      ),
      _MarkdownBlockType.paragraph => Text.rich(
        TextSpan(
          children: _inlineSpans(
            context,
            block.text,
            onTapLink: onTapLink,
            baseStyle: bodyStyle,
          ),
        ),
      ),
      _MarkdownBlockType.unorderedList || _MarkdownBlockType.orderedList => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: block.type == _MarkdownBlockType.orderedList
                ? Text(
                    '${block.ordinal}.',
                    style: bodyStyle?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: _inlineSpans(
                  context,
                  block.text,
                  onTapLink: onTapLink,
                  baseStyle: bodyStyle,
                ),
              ),
            ),
          ),
        ],
      ),
      _MarkdownBlockType.quote => Container(
        decoration: BoxDecoration(
          color: scheme.secondaryContainer.withValues(alpha: 0.36),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: scheme.secondary),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Text.rich(
                    TextSpan(
                      children: _inlineSpans(
                        context,
                        block.text,
                        onTapLink: onTapLink,
                        baseStyle: bodyStyle?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      _MarkdownBlockType.code => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.72),
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(
            block.text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface,
              fontFamily: 'monospace',
              height: 1.5,
            ),
          ),
        ),
      ),
      _MarkdownBlockType.rule => Divider(
        color: scheme.outlineVariant.withValues(alpha: 0.72),
        height: 12,
      ),
    };

    return Padding(
      padding: EdgeInsets.only(
        bottom: switch (block.type) {
          _MarkdownBlockType.heading => 10,
          _MarkdownBlockType.rule => 10,
          _ => 12,
        },
      ),
      child: child,
    );
  }
}

List<InlineSpan> _inlineSpans(
  BuildContext context,
  String source, {
  required TextStyle? baseStyle,
  required ReleaseNotesLinkCallback? onTapLink,
}) {
  final scheme = Theme.of(context).colorScheme;
  final spans = <InlineSpan>[];
  final tokenPattern = RegExp(
    r'(\*\*[^\n*]+\*\*|__[^\n_]+__|~~[^\n~]+~~|`[^`\n]+`|\[[^\]\n]+\]\([^)\n]+\)|\*[^\n*]+\*|_[^\n_]+_)',
  );
  var cursor = 0;

  for (final match in tokenPattern.allMatches(source)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: source.substring(cursor, match.start)));
    }
    final token = match.group(0)!;
    if ((token.startsWith('**') && token.endsWith('**')) ||
        (token.startsWith('__') && token.endsWith('__'))) {
      spans.add(
        TextSpan(
          text: token.substring(2, token.length - 2),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      );
    } else if (token.startsWith('~~') && token.endsWith('~~')) {
      spans.add(
        TextSpan(
          text: token.substring(2, token.length - 2),
          style: const TextStyle(decoration: TextDecoration.lineThrough),
        ),
      );
    } else if (token.startsWith('`') && token.endsWith('`')) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              token.substring(1, token.length - 1),
              style: baseStyle?.copyWith(
                color: scheme.onSurface,
                fontFamily: 'monospace',
                fontSize: (baseStyle.fontSize ?? 14) - 1,
                height: 1.2,
              ),
            ),
          ),
        ),
      );
    } else if (token.startsWith('[')) {
      final separator = token.lastIndexOf('](');
      final label = token.substring(1, separator);
      final uri = Uri.tryParse(
        token.substring(separator + 2, token.length - 1),
      );
      final canOpen =
          uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          onTapLink != null;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Semantics(
            link: canOpen,
            child: InkWell(
              onTap: canOpen ? () => onTapLink(uri) : null,
              borderRadius: BorderRadius.circular(4),
              child: Text(
                label,
                style: baseStyle?.copyWith(
                  color: canOpen ? scheme.primary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  decoration: canOpen ? TextDecoration.underline : null,
                  decorationColor: scheme.primary.withValues(alpha: 0.56),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      spans.add(
        TextSpan(
          text: token.substring(1, token.length - 1),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    }
    cursor = match.end;
  }

  if (cursor < source.length) {
    spans.add(TextSpan(text: source.substring(cursor)));
  }
  return [TextSpan(style: baseStyle, children: spans)];
}

enum _MarkdownBlockType {
  heading,
  paragraph,
  unorderedList,
  orderedList,
  quote,
  code,
  rule,
}

class _MarkdownBlock {
  const _MarkdownBlock(
    this.type,
    this.text, {
    this.level = 0,
    this.ordinal = 0,
  });

  final _MarkdownBlockType type;
  final String text;
  final int level;
  final int ordinal;

  static List<_MarkdownBlock> parse(String source) {
    final lines = source
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final blocks = <_MarkdownBlock>[];
    final paragraph = <String>[];
    var inCodeBlock = false;
    final codeLines = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      blocks.add(
        _MarkdownBlock(
          _MarkdownBlockType.paragraph,
          paragraph.map((line) => line.trim()).join(' '),
        ),
      );
      paragraph.clear();
    }

    for (final line in lines) {
      final trimmed = line.trimRight();
      if (trimmed.trimLeft().startsWith('```')) {
        flushParagraph();
        if (inCodeBlock) {
          blocks.add(
            _MarkdownBlock(_MarkdownBlockType.code, codeLines.join('\n')),
          );
          codeLines.clear();
        }
        inCodeBlock = !inCodeBlock;
        continue;
      }
      if (inCodeBlock) {
        codeLines.add(line);
        continue;
      }
      if (trimmed.trim().isEmpty) {
        flushParagraph();
        continue;
      }

      final heading = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(trimmed);
      if (heading != null) {
        flushParagraph();
        blocks.add(
          _MarkdownBlock(
            _MarkdownBlockType.heading,
            heading.group(2)!.trim(),
            level: heading.group(1)!.length,
          ),
        );
        continue;
      }
      if (RegExp(
        r'^\s*((\*\s*){3,}|(-\s*){3,}|(_\s*){3,})\s*$',
      ).hasMatch(trimmed)) {
        flushParagraph();
        blocks.add(const _MarkdownBlock(_MarkdownBlockType.rule, ''));
        continue;
      }
      final unordered = RegExp(r'^\s*[-+*]\s+(.+)$').firstMatch(trimmed);
      if (unordered != null) {
        flushParagraph();
        blocks.add(
          _MarkdownBlock(
            _MarkdownBlockType.unorderedList,
            unordered.group(1)!.trim(),
          ),
        );
        continue;
      }
      final ordered = RegExp(r'^\s*(\d+)[.)]\s+(.+)$').firstMatch(trimmed);
      if (ordered != null) {
        flushParagraph();
        blocks.add(
          _MarkdownBlock(
            _MarkdownBlockType.orderedList,
            ordered.group(2)!.trim(),
            ordinal: int.tryParse(ordered.group(1)!) ?? 1,
          ),
        );
        continue;
      }
      final quote = RegExp(r'^\s*>\s?(.+)$').firstMatch(trimmed);
      if (quote != null) {
        flushParagraph();
        blocks.add(
          _MarkdownBlock(_MarkdownBlockType.quote, quote.group(1)!.trim()),
        );
        continue;
      }
      paragraph.add(trimmed);
    }

    flushParagraph();
    if (codeLines.isNotEmpty) {
      blocks.add(_MarkdownBlock(_MarkdownBlockType.code, codeLines.join('\n')));
    }
    return blocks;
  }
}
