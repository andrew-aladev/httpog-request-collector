#!/bin/bash
set -e

DIR=$(dirname "${BASH_SOURCE[0]}")
cd "$DIR"

cd "../.."

TMP_PATH="$(pwd)/tmp"
TMP_SIZE="1024"

./scripts/temp/mount.sh "$TMP_PATH" "$TMP_SIZE"

./lib/update_urls/main.rb \
  "data/valid_page_urls.xz" \
  "data/invalid_page_urls.xz" \
  "data/log_urls.xz"
