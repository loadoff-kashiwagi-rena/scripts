# GitHub Issues → Google Sheets 自動同期

GitHub の open Issue の進捗をGoogle Sheetsに自動で書き込むシェルスクリプトです。

## 概要

- GitHub Issues の open なタスクを取得
- 各 Issue のコメントから `進捗：XX%` を抽出
- `タスク名(7日前の進捗%→最新進捗%)` の形式でGoogle Sheetsに書き込む

## 使用ツール

| ツール | 用途 |
|---|---|
| `gh`（GitHub CLI） | GitHub Issues の取得 |
| `jq` | JSON データの整形・抽出 |
| `gws`（Google Workspace CLI） | Google Sheets への書き込み |

## 前提条件

- macOS
- Homebrew がインストール済み
- Google Cloud Project が作成済み
- Google Sheets API が有効化済み
- OAuth クライアントID（デスクトップアプリ）が作成済み

## セットアップ

### 1. 必要なツールのインストール

```bash
# GitHub CLI
brew install gh

# jq
brew install jq

# Google Workspace CLI
npm install -g @googleworkspace/cli
```

### 2. 各ツールの認証

```bash
# GitHub 認証
gh auth login

# Google Workspace 認証
# ※ 事前に client_secret.json を ~/.config/gws/ に配置すること
mkdir -p ~/.config/gws
mv ~/Downloads/client_secret_*.json ~/.config/gws/client_secret.json
gws auth login -s sheets
```

### 3. 環境変数の設定

`.env.example` をコピーして `.env` を作成する：

```bash
cp .env.example .env
```

`.env` に実際の値を記入する：

```
REPO="オーナー名/リポジトリ名"
SPREADSHEET_ID="スプレッドシートID"
```

> ⚠️ `.env` には機密情報が含まれます。絶対にコミットしないでください。

### 4. 実行権限の付与

```bash
chmod +x sync_issues.sh
```

## 使い方

```bash
./sync_issues.sh
```

## ファイル構成

```
.
├── sync_issues.sh   # スクリプト本体
├── .env             # 環境変数（コミット禁止）
├── .env.example     # 環境変数のテンプレート
└── .gitignore       # .env を除外する設定
```

## コメントのフォーマット

Issue のコメントに以下のフォーマットで進捗を記載する：

```
進捗：XX%
```

- コロンは全角「：」
- `%` は半角
- 数字は半角
- スペースなし

## Sheets の出力イメージ

| タスク名 | 最新進捗 |
|---|---|
| 現行のerror画面を持ってくる(0%→30%) | 30% |
| ログイン画面のバグ修正(0%→60%) | 60% |

## セキュリティ注意事項

- `.env` は絶対に GitHub にコミットしない
- `~/.config/gws/client_secret.json` は第三者に共有しない
- `gws auth login -s sheets` で必要最小限のスコープのみ付与する
- OAuth クライアントの秘密鍵が漏れた場合は Google Cloud Console から即座に削除する