#!/bin/bash
set -e

DIR=$(dirname "${BASH_SOURCE[0]}")
cd "$DIR"

cd "../.."

echo "" | zstd -c > "data/valid_log_urls.zst"
cp "data/valid_log_urls.zst" "data/invalid_log_urls.zst"
cp "data/valid_log_urls.zst" "data/requests_with_special_symbols.zst"
