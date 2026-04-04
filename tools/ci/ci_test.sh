#!/bin/bash

# Run the tests in Github Action
#
# Failed tests run up to three times, to take into account flakey tests.
# Of course the random generator is not re-seeded between runs, in order to
# repeat the same result.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Run from the tests directory and point Python at the inner source trees.
# The repository root also contains packaging directories named `psycopg`
# and `psycopg_pool`, which Python would otherwise import as namespace
# packages before the actual project code.
export PYTHONPATH="$repo_root/psycopg:$repo_root/psycopg_pool${PYTHONPATH:+:$PYTHONPATH}"
cd "$repo_root/tests"

# Assemble a markers expression from the MARKERS and NOT_MARKERS env vars
markers=""
for m in ${MARKERS:-}; do
    [[ "$markers" != "" ]] && markers="$markers and"
    markers="$markers $m"
done
for m in ${NOT_MARKERS:-}; do
    [[ "$markers" != "" ]] && markers="$markers and"
    markers="$markers not $m"
done

pytest="python -bb -m pytest --color=yes"

$pytest -m "$markers" "$@" && exit 0

$pytest -m "$markers" --lf --randomly-seed=last "$@" && exit 0

$pytest -m "$markers" --lf --randomly-seed=last "$@"
