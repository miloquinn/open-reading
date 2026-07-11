# Copilot instructions for open-reading

This repository is a cross-platform Flutter/Dart reading application. When reviewing or changing code:

- Prioritize correctness, regressions, data loss, privacy, and security over style suggestions.
- Pay special attention to book import and parsing, filesystem paths, archive extraction, database migrations, encodings, large-file memory use, and platform-specific behavior.
- Flag unbounded reads, unsafe archive paths, silent exception swallowing, destructive migrations, and behavior changes without tests.
- Verify that user-visible strings use the localization system and that relevant English and Chinese ARB resources stay aligned.
- Treat `lib/l10n/app_localizations*.dart` and platform plugin registrant files as generated unless the pull request intentionally updates generated output.
- Ask for focused tests when business logic changes. Do not treat passing lint or tests as proof that a behavior change is correct.
- Keep review comments concrete: identify the affected behavior, the triggering input or platform, and a practical fix.
- Never recommend automatic merging. The repository owner must make the final merge decision manually.

