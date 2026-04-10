#!/bin/bash

# .envを読み込む
source "$(dirname "$0")/.env"


# シートのToDo列(F列)から既存のToDo文字列を取得
EXISTING=$(gws sheets +read \
  --spreadsheet "$SPREADSHEET_ID" \
  --range "${SHEET_NAME}!F:F" \
  | jq -r '.values[]?[0] // empty')

# open な Issue 一覧を取得
gh issue list -R "$REPO" --state open --json number,title \
  | jq -r '.[] | "\(.number) \(.title)"' \
  | while read -r number title; do

    # 各IssueのコメントからIssue作成日と最新進捗を取得
    DATA=$(gh issue view "$number" -R "$REPO" --json title,comments,createdAt)

    # 最新の進捗を取得（コメントから「進捗：XX%」を抽出、なければ0）
    LATEST=$(echo "$DATA" \
      | jq -r '
        [.comments[].body
         | capture("進捗：(?<x>[0-9]+)%")
         | .x] | if length > 0 then .[-1] else "0" end')

    # 7日前の進捗を取得
    SEVEN_DAYS_AGO=$(date -v-7d +%Y-%m-%dT%H:%M:%SZ)
    SEVEN_AGO=$(echo "$DATA" \
      | jq -r --arg date "$SEVEN_DAYS_AGO" '
        [.comments[]
         | select(.createdAt <= $date)
         | .body
         | capture("進捗：(?<x>[0-9]+)%")
         | .x] | if length > 0 then .[-1] else "0" end')

    # 「タスク名 #番号(7日前%→最新%)」の形式に整形
    LABEL="${title} #${number}(${SEVEN_AGO}%→${LATEST}%)"

    # 既存のToDoに同じ文字列があればスキップ
    if echo "$EXISTING" | grep -qxF "$LABEL"; then
      echo "スキップ（既存）：$LABEL"
      continue
    fi

    # 今日の日付（MM/DD形式）
    TODAY=$(date +%m/%d)

    echo "書き込み中：$LABEL"

    # シートに追記（A列:開始日, F列:ToDo）
    gws sheets spreadsheets values append \
      --params "{\"spreadsheetId\": \"${SPREADSHEET_ID}\", \"range\": \"${SHEET_NAME}!A:G\", \"valueInputOption\": \"USER_ENTERED\", \"insertDataOption\": \"INSERT_ROWS\"}" \
      --json "{\"values\": [[\"${TODAY}\",\"\",\"\",\"\",\"\",\"${LABEL}\"]]}"

done

# --- クローズ済みissueの完了日を更新 ---
# シート全体を読み取り、issue番号があって完了日が空の行を探す
SHEET_DATA=$(gws sheets +read \
  --spreadsheet "$SPREADSHEET_ID" \
  --range "${SHEET_NAME}!A:G")

ROW_COUNT=$(echo "$SHEET_DATA" | jq '.values | length')

for (( i=1; i<ROW_COUNT; i++ )); do
  # B列(完了日)が空かチェック
  DONE_DATE=$(echo "$SHEET_DATA" | jq -r ".values[$i][1] // \"\"")
  [ -n "$DONE_DATE" ] && continue

  # F列(ToDo)からissue番号を抽出
  TODO=$(echo "$SHEET_DATA" | jq -r ".values[$i][5] // \"\"")
  ISSUE_NUM=$(echo "$TODO" | grep -oE '#[0-9]+' | head -1 | tr -d '#')
  [ -z "$ISSUE_NUM" ] && continue

  # GitHubでissueの状態を確認
  ISSUE_DATA=$(gh issue view "$ISSUE_NUM" -R "$REPO" --json state,closedAt 2>/dev/null)
  [ $? -ne 0 ] && continue

  STATE=$(echo "$ISSUE_DATA" | jq -r '.state')
  [ "$STATE" != "CLOSED" ] && continue

  # クローズ日をMM/DD形式に変換
  CLOSED_AT=$(echo "$ISSUE_DATA" | jq -r '.closedAt')
  CLOSED_DATE=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$CLOSED_AT" +%m/%d 2>/dev/null)

  ROW_NUM=$((i + 1))
  echo "完了日更新：#${ISSUE_NUM} → ${CLOSED_DATE} (行${ROW_NUM})"

  # B列(完了日)を更新
  gws sheets spreadsheets values update \
    --params "{\"spreadsheetId\": \"${SPREADSHEET_ID}\", \"range\": \"${SHEET_NAME}!B${ROW_NUM}\", \"valueInputOption\": \"USER_ENTERED\"}" \
    --json "{\"values\": [[\"${CLOSED_DATE}\"]]}"
done

echo "完了！"
