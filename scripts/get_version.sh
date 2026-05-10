#!/bin/bash
set -eou pipefail

UPSTREAM_OWNER=elastic
UPSTREAM_REPO=ml-cpp


git ls-remote --tags --refs https://github.com/$UPSTREAM_OWNER/$UPSTREAM_REPO.git \
    | cut -d'/' -f3- \
    | cut -d'^' -f1 \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -V \
    | tail -n1
