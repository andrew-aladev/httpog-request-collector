#!/bin/bash
set -e

DIR=$(dirname "${BASH_SOURCE[0]}")
cd "$DIR"

cd "../.."

TMP_PATH="$(pwd)/tmp"
TMP_SIZE="1024"

./scripts/temp/mount.sh "$TMP_PATH" "$TMP_SIZE"

./lib/process_requests/main.rb \
  "data/log_urls.xz" \
  "data/valid_log_urls.xz" \
  "data/invalid_log_urls.xz" \
  "data/requests_with_special_symbols.xz"
