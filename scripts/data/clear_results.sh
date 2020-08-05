#!/bin/bash
set -e

DIR=$(dirname "${BASH_SOURCE[0]}")
cd "$DIR"

cd "../.."

empty_data=$(echo "" | zstd -c)

echo "$empty_data" > "data/valid_log_urls.zst"
echo "$empty_data" > "data/invalid_log_urls.zst"
echo "$empty_data" > "data/requests_with_special_symbols.zst"
