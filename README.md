# Gemini News Scheduler (Flutter / Android)

Gemini 1.5 Flash を使って、ユーザー設定のキーワードを基に最新ニュースを取得し、
ローカル保存（7日保持）および端末通知を行うアプリです。

## 技術スタック

- Flutter（stable）
- 状態管理: `flutter_riverpod` + `riverpod_generator`
- ローカルDB: `isar`
- API: `google_generative_ai`（Gemini 1.5 Flash / search grounding）
- バックグラウンド: `workmanager`
- 通知: `flutter_local_notifications`
- ルーティング: `go_router`
- 補助: `shared_preferences`, `intl`, `collection`, `freezed_annotation`（将来的な拡張前提）

## アーキテクチャ

本プロジェクトは `features/<domain>/...` の3層を意識した構成です。

- `domain`: Entity / Repository interface / UseCase
- `data`: API/DataSource（Gemini, Isar）と Repository 実装
- `presentation`: Riverpod Provider/Controller、画面、ルーティング
- `scheduler`: WorkManager ハンドラ、スケジューラ設定、再試行判定
- `notification`: ローカル通知サービス
- `errors`: `AppError` による分類とユーザー向けメッセージ

## 画面構成

- `NewsHomePage`: 記事一覧、手動取得、エラー表示
- `SettingsPage`: APIキー/キーワード/通知有無/実行時刻の編集
- `NewsDetailPage`: 記事詳細
- `GeminiChatPage`: Gemini 接続確認用の簡易チャット

## 主要フロー

1. 起動時: `App` で通知初期化と `Workmanager` の初期化
2. `SchedulerService.restoreScheduleOnAppStart()` で保存設定を復元し、必要なら次回実行を再登録
3. 指定時刻: WorkManager が `newsWorkerDispatcher` を起動
4. 背景処理で Gemini 取得 → 重複排除 → Isar へ保存
5. 取得後に 7 日以上経過した記事を削除
6. 成功/失敗の結果を通知

## 依存追加

```bash
flutter pub add flutter_riverpod riverpod_annotation go_router isar isar_flutter_libs \
  google_generative_ai workmanager flutter_local_notifications shared_preferences intl \
  freezed_annotation json_annotation collection

flutter pub add --dev build_runner riverpod_generator isar_generator
```

## 実行手順

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

### Gemini APIキー設定（記事準拠の段階実装）

1. `.env.example` をコピーして `.env` を作成
2. `.env` の `API_KEY` に Gemini API キーを設定

```bash
cp .env.example .env
```

`.env` 例:

```text
API_KEY=your_gemini_api_key_here
```

アプリ起動時に `.env` を読み込みます。`.env` が未設定の場合は、設定画面で保存した API キー、または `--dart-define=GEMINI_API_KEY=...` を使用します。

### ステップ1: Geminiチャット接続確認

記事の流れに合わせ、まずは Gemini の接続確認用チャット画面を追加しています。

1. ホーム画面右上のチャットアイコンをタップ
2. メッセージを送信
3. Gemini 応答が表示されることを確認

### APIキーの渡し方（任意）

- 設定画面で入力保存
- または、起動時に `--dart-define=GEMINI_API_KEY=...` を利用

## エラーと再試行方針

`AppError` で分類しています。

- `network`: 通信エラー。再試行可
- `quota`: Gemini クォータ上限。再試行可
- `storage`: DB/保存処理エラー。再試行可
- `authentication`: APIキー未設定など。再試行不可
- `parse`: レスポンス形式不正など。再試行不可
- `unknown`: 例外が上手く分類できない場合。再試行可

### 再試行

`failureCount` を元に指数寄りの間隔で再試行します。

- 1回目: 2分
- 2回目: 10分
- 3回目以降: 30分

3回を超える場合は追加再試行を行わず、最終エラー通知へ遷移します。

## Android 実機確認観点

1. 開発端末で以下を許可
   - 通知権限（Android 13 以降）
   - 省電力設定によるバックグラウンド制限
2. 設定画面で実行時刻・キーワード・APIキーを保存
3. 起動時にスケジュール再登録が走ることを確認
4. 指定時刻前後で自動取得が発生することを確認
5. 取得結果が一覧へ反映されることを確認
6. 7日以上前の記事が消えることを確認
7. 取得失敗時の通知内容と再試行回数が表示されることを確認
8. 手動「今すぐ実行」で即時取得できることを確認

## 補足

- 初回はバックグラウンド実行が端末依存のため、デバッグでは手動実行で主要ロジックを検証し、動作確認後に実時間の自動実行を確認してください。
