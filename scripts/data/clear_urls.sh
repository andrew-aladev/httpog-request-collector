#!/bin/bash
set -e

DIR=$(dirname "${BASH_SOURCE[0]}")
cd "$DIR"

cd "../.."

echo -n "" | zstd -c > "data/valid_page_urls.zst"
cp "data/valid_page_urls.zst" "data/invalid_page_urls.zst"
cp "data/valid_page_urls.zst" "data/log_urls.zst"
