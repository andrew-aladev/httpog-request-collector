#!/bin/bash
set -e

DIR=$(dirname "${BASH_SOURCE[0]}")
cd "$DIR"

cd "../.."

./lib/requests_with_special_symbols.rb "data/requests_with_special_symbols.xz"
