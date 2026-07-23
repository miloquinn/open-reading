import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/widgets/release_notes_markdown.dart';

void main() {
  testWidgets('renders common release-note Markdown blocks and links', (
    tester,
  ) async {
    Uri? openedUri;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReleaseNotesMarkdown(
              data: '''# Highlights

Regular **bold** and *italic* text with `inline code`.

- First item
1. Ordered item

> Important note

```dart
final version = '2.0.0';
```

[Release page](https://example.com/releases/2.0.0)''',
              onTapLink: (uri) async => openedUri = uri,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Highlights'), findsOneWidget);
    expect(find.text('First item'), findsOneWidget);
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('Ordered item'), findsOneWidget);
    expect(find.text('Important note'), findsOneWidget);
    expect(find.text("final version = '2.0.0';"), findsOneWidget);
    expect(find.text('inline code'), findsOneWidget);

    await tester.tap(find.text('Release page'));
    expect(openedUri, Uri.parse('https://example.com/releases/2.0.0'));
  });
}
