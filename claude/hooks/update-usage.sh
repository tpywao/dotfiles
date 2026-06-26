#!/bin/bash
# SessionStart hook: Claude Code の利用量を集計してダッシュボードを再生成する。
# セッション開始を遅延させないようバックグラウンドで起動して即終了する。
command -v python3 >/dev/null 2>&1 && python3 "$HOME/.claude/usage/collect.py" >/dev/null 2>&1 &
exit 0
