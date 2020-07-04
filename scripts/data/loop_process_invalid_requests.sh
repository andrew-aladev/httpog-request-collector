#!/bin/bash
set -e

DIR=$(dirname "${BASH_SOURCE[0]}")
cd "$DIR"

while true; do
  ./process_invalid_requests.sh
done
