#!/bin/bash

# Run the tests in Github Action
#
# Failed tests run up to three times, to take into account flakey tests.
# Of course the random generator is not re-seeded between runs, in order to
# repeat the same result.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# The repository root contains packaging directories named `psycopg` and
# `psycopg_pool`, which would shadow the actual project packages if the test
# runner imported them directly from the current working directory. Adjust
# `sys.path` before importing pytest so the inner source trees take precedence
# without changing into `tests/`, which would make `tests/types` shadow the
# standard library `types` module on Windows. Also export the same source-tree
# paths for subprocesses spawned by the test suite, and use `PYTHONSAFEPATH`
# so child interpreters don't prepend the repository root back onto `sys.path`.
export PYTHONPATH="$repo_root/psycopg:$repo_root/psycopg_pool${PYTHONPATH:+:$PYTHONPATH}"
export PYTHONSAFEPATH=1

pytest_runner='
import os
import sys

repo_root = os.path.abspath(sys.argv[1])
source_paths = [
    os.path.join(repo_root, "psycopg"),
    os.path.join(repo_root, "psycopg_pool"),
]
blocked_paths = {
    repo_root,
    os.path.join(repo_root, "tests"),
}
sys.path[:] = source_paths + [p for p in sys.path if os.path.abspath(p or os.curdir) not in blocked_paths]

import pytest

raise SystemExit(pytest.main(sys.argv[2:]))
'

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

pytest=(python -bb -c "$pytest_runner" "$repo_root" --color=yes)

"${pytest[@]}" -m "$markers" "$@" && exit 0

"${pytest[@]}" -m "$markers" --lf --randomly-seed=last "$@" && exit 0

"${pytest[@]}" -m "$markers" --lf --randomly-seed=last "$@"
