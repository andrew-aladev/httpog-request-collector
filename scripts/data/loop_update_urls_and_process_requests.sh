#!/bin/bash
set -e

DIR=$(dirname "${BASH_SOURCE[0]}")
cd "$DIR"

PROCESS_REQUESTS_TIMES=5
UPDATE_URLS_TIMES=5

while true; do
  for i in $(seq $PROCESS_REQUESTS_TIMES); do
    for i in $(seq $UPDATE_URLS_TIMES); do
      ./update_urls.sh
    done

    ./process_requests.sh
  done

  ./process_invalid_requests.sh
done
