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

# Flutter Design & UI Skills

- UI framework: Flutter 3.x (Material 3 / Adaptive Design)
- State Management: Riverpod (prefer Functional Widgets)
- Design Tokens: Reference `lib/theme/tokens.g.dart` for colors/spacing.
- Anti-Patterns: Avoid deeply nested build methods; extract to small stateless widgets.
- Optimization: Use `const` constructors everywhere possible for repainting efficiency.

## News/Feed UI Specifics

- **Card Design**: Use `Card` with `elevation: 0` and a subtle `BorderSide` for a modern, flat look.
- **Typography**: News headlines must use `titleLarge` with `fontWeight: FontWeight.bold` and `maxLines: 2`.
- **Imagery**: Use `ClipRRect` (border-radius: 12) for news thumbnails. Implement a shimmer effect (loading state) for `Image.network`.
- **Layout**: For news lists, use `SliverList` to ensure smooth scrolling. Add horizontal padding (16px) consistent with the system's `AppSpacing`.
- **Visual Hierarchy**: Use `LabelSmall` with `colorScheme.onSurfaceVariant` for "Time ago" or "Source" metadata to de-emphasize non-essential info.
