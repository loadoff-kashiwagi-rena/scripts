#!/bin/bash

# .envを読み込む
source "$(dirname "$0")/.env"

# open な Issue 一覧を取得
gh issue list -R "$REPO" --state open --json number,title \
  | jq -r '.[] | "\(.number) \(.title)"' \
  | while read -r number title; do

    # 各IssueのコメントからIssue作成日と最新進捗を取得
    DATA=$(gh issue view "$number" -R "$REPO" --json title,comments,createdAt)

    # 最新の進捗を取得（コメントがない場合は0%）
    LATEST=$(echo "$DATA" \
      | jq -r 'if .comments | length > 0
               then .comments[-1].body | gsub("進捗：(?<x>[0-9]+)%"; "\(.x)")
               else "0"
               end')

    # 7日前の進捗を取得
    SEVEN_DAYS_AGO=$(date -v-7d +%Y-%m-%dT%H:%M:%SZ)
    SEVEN_AGO=$(echo "$DATA" \
      | jq -r --arg date "$SEVEN_DAYS_AGO" '
        .comments
        | map(select(.createdAt <= $date))
        | if length > 0
          then .[-1].body | gsub("進捗：(?<x>[0-9]+)%"; "\(.x)")
          else "0"
          end')

    # 「タスク名(7日前→最新)」の形式に整形
    LABEL="${title}(${SEVEN_AGO}%→${LATEST}%)"

    echo "書き込み中：$LABEL"

    # Sheetsに書き込む
    gws sheets +append \
      --spreadsheet "$SPREADSHEET_ID" \
      --values "$LABEL,$LATEST%"

done

echo "完了！"