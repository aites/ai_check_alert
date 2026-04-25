# Flutter/Dart Project Rules

## Coding Standards

- Adhere to "Effective Dart" guidelines.
- Prefer `const` constructors whenever possible.
- Use `final` for all variables that do not change.
- Never use helper methods to return Widgets; create a separate `StatelessWidget` or `StatefulWidget` class instead.

## State Management (Riverpod)

- Use Riverpod with the `@riverpod` generator.
- Prefer `AsyncNotifier` for asynchronous logic.
- UI components must extend `ConsumerWidget` or `ConsumerStatefulWidget`.

## UI & Styling

- Follow Material 3 design principles.
- Use `context.textTheme` or `context.colorScheme` instead of hardcoded colors/styles.
- Ensure all screens are responsive using `LayoutBuilder` or custom breakpoints.

## Error Handling

- Use `Result` patterns or `Either` for functional error handling in the domain layer.
- Always provide a user-friendly error UI for `AsyncValue.error` states.

## Technical Stack

- Flutter / Riverpod (NotifierProvider)
- Gemini API (google_generative_ai)
- Environment: flutter_dotenv
- DB: sqflite
- Background: workmanager

## Strict Rules

- **Security:** NEVER hardcode API keys. Always use `dotenv.env['GEMINI_API_KEY']`.
- **Immutability:** All state must be immutable using `@freezed`. Always include `part 'filename.freezed.dart';` and `part 'filename.g.dart';`.
- **Background Tasks:** The Workmanager `callbackDispatcher` and its tasks MUST be **top-level functions**.
- **Data Retention:** Database cleanup (deleting data older than 14 days) must execute immediately after the Workmanager fetches new data.
- **Architecture:** Use clean architecture: Separate UI, Business Logic (Providers), and Services (API/DB).
