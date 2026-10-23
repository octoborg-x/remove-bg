#!/usr/bin/env bash
set -euo pipefail
OWNER="octoborg-x"
REPO="octoborg-x/remove-bg"
export OPENHANDS_SUPPRESS_BANNER=1
export LLM_MODEL="${LLM_MODEL:-gemini/gemini-2.5-flash}"
export PATH="$HOME/.local/bin:$PATH"

# owner-only feedback, collected outside the agent
gh pr list --repo "$REPO" --state all --limit 15 \
  --json number,title,state,mergedAt,comments \
  --jq "[.[]|{number,title,state,mergedAt,owner_comments:[.comments[]|select(.author.login==\"$OWNER\")|.body]}]" \
  > /tmp/feedback.json || echo "[]" > /tmp/feedback.json

curl -LsSf https://astral.sh/uv/install.sh | sh
uv tool install openhands --python 3.12

BRANCH="autopay/$(date -u +%Y%m%d-%H%M)"
git checkout -b "$BRANCH"

# agent runs WITHOUT any GitHub token
env -u GH_TOKEN -u GITHUB_TOKEN \
  openhands --headless --override-with-envs -f PROMPT.md

git config user.name "autopay-bot"
git config user.email "autopay-bot@users.noreply.github.com"
git add -A
if git diff --cached --quiet; then echo "No changes"; exit 0; fi
git commit -m "autopay cycle $BRANCH"
git push "https://x-access-token:${GH_TOKEN}@github.com/${REPO}.git" "$BRANCH"
gh pr create --repo "$REPO" --base main --head "$BRANCH" \
  --title "AUTOPAY $BRANCH" \
  --body "Merge = approve. Comment REJECT: reason to decline."
