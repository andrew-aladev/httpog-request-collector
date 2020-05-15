#!/bin/bash
set -e

DIR=$(dirname "${BASH_SOURCE[0]}")
cd "$DIR"

cd "../.."

truncate --size=0 \
  "data/valid_page_urls.xz" \
  "data/invalid_page_urls.xz" \
  "data/log_urls.xz"
