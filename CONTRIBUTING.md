# Contributing to Open Reading

Thank you for contributing to Open Reading. By submitting a contribution, you
agree that your contribution is licensed under the repository's current
`AGPL-3.0-only` license and that you have the right to provide it under those
terms.

Do not submit code, assets, book-source rules, books, or other material that you
do not have permission to redistribute. Third-party code or assets must include
clear provenance and compatible license information.

Before opening a pull request, run:

```bash
flutter pub get --enforce-lockfile
flutter gen-l10n
git diff --exit-code -- lib/l10n
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test --coverage
flutter build apk --debug
```

GitHub Actions repeats these checks for pull requests and pushes to `main`.
It also runs a non-blocking Web release build so Web compatibility regressions
remain visible while the current JavaScript integer compatibility gap is open.
Linux, Windows, macOS, and unsigned iOS release builds also run when relevant
application or platform files change, on a weekly schedule, and on demand.

See [LICENSING.md](LICENSING.md) for the boundary between historical MIT
revisions and current AGPL-3.0 revisions.
