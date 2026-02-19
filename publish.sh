#!/usr/bin/env bash
set -euo pipefail

rsync -av --delete \
  --exclude '_site' \
  --exclude '_book' \
  --exclude '.quarto' \
  --exclude '.DS_Store' \
  --exclude '.git' \
  ../Patterns-from-static/pos-book/ \
  ./pos-book/

git add pos-book
git commit -m "Update web book" || echo "No changes to commit."
git push
