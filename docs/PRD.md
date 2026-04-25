# AI Daily News Personalizer: 詳細要求仕様書 (Final PRD)

## 1. プロジェクト概要

ユーザーの関心事（トピック）に基づき、Gemini APIが最新ニュースを検索・要約。毎朝自動でパーソナライズされたニュースフィードを提供するFlutterアプリ。

## 2. 技術スタック & 開発環境

- **IDE:** VSCode (GitHub Copilot / GPT-5.3-Codex Medium)
- **Framework:** Flutter (Material 3)
- **State Management:** Riverpod (with `@riverpod` generator)
- **AI SDK:** `google_generative_ai`
  - **Model Candidates:** - `gemini-2.5-flash` (Primary)
    - `gemini-2.0-flash`, `gemini-2.0-flash-lite`
    - `gemini-1.5-flash-latest`, `gemini-1.5-pro-latest`
- **Database:** `isar` (Local NoSQL)
- **Background:** `workmanager`
- **Other:** `flutter_local_notifications`, `flutter_dotenv`

## 3. データ構造定義 (JSON / Isar Schema)

APIレスポンスおよび内部DB共通の構造を厳守する。

```json
{
  "date": "YYYY-MM-DD",
  "articles": [
    {
      "id": "String (UUID)",
      "title": "String",
      "summary": "String (3行程度の要約)",
      "content": "String (詳細本文)",
      "category": "String",
      "source_url": "String",
      "importance": "Integer (1-5)"
    }
  ]
}
```

## 4. 機能要件

### A. AIニュース生成・同期ロジック

- **検索グラウンディング:** Google Search Groundingを有効化し、直近24時間以内の情報を取得。
- **厳格なフォーマット制御:** 指定JSON以外のアウトプットを禁止（挨拶、解説の排除）。
- **冪等性の担保:** `source_url`をキーとし、重複する記事はDB保存をスキップする。

### B. バックグラウンド処理 & 通知

- **定期実行:** `workmanager`により24時間周期で実行（ユーザー指定時刻）。
- **ワークフロー:** 1.トピック取得 → 2.API実行 → 3.Isar保存 → 4.ローカル通知発行。

### C. ライフサイクル管理（データクリーンアップ）

- **自動パージ:** 保存から**14日**を経過したデータを、バックグラウンド処理完了時またはアプリ起動時に物理削除する。

### D. UI/UX 仕様

- **Home:** 最新記事を重視したカード型リスト（日付によるグルーピング）。
- **Settings:** APIキー（`dotenv`管理）、トピック、通知時刻設定。

## 5. フォルダ構成案 (Clean Architecture準拠)

```text
lib/
 ├── core/              # Constants, Theme, Env, Utils
 ├── data/
 │    ├── models/       # Isar Schemas (@collection)
 │    ├── services/     # Gemini (Search Grounding), Isar, Notification
 │    └── repository/   # Data handling & Synchronization
 ├── providers/         # Riverpod (AsyncNotifier)
 ├── ui/
 │    ├── views/        # Home, Detail, Settings
 │    └── widgets/      # NewsCard, CategoryChip
 └── background/        # Workmanager Dispatcher
```

## 6. AIシステムプロンプト

```text
Role: プロフェッショナル・ニュースエディター
Task: ユーザー指定の[Topic]に関し、Google検索を用いて24時間以内の最新ニュースを最大5件収集・要約せよ。
Rules:
1. 事実に基づかない生成（ハルシネーション）を厳禁とする。
2. 信頼できるソースがない場合は空のリスト `[]` を返せ。
3. 出力は定義されたJSONフォーマットのみ。解説や挨拶は一切不要。
```

## 7. 実装ロードマップ

1. **Phase 1 (Foundations):** `pubspec.yaml`構成、Isarモデル定義、`flutter_dotenv`環境構築。
2. **Phase 2 (AI Service):** Gemini APIクライアントの実装。Search Groundingの統合。
3. **Phase 3 (Persistence & BG):** Workmanagerによるバックグラウンド同期と通知。14日間自動削除ロジック。
4. **Phase 4 (UI/UX):** Riverpodを用いたステート管理、Home/Settings画面の実装。
