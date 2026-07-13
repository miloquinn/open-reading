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
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

See [LICENSING.md](LICENSING.md) for the boundary between historical MIT
revisions and current AGPL-3.0 revisions.
