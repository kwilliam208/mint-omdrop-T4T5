#!/bin/bash
# Run the unit tests. The single entry point for CI and developers:
#   tools/run-tests.sh                the bats tests in tests/unit, then the
#                                     Python tests in tests/
#   tools/run-tests.sh <file.bats>... only those bats files
# tests/test_owl_*.py skip until tools/build-owl.sh has patched OWL.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
command -v bats >/dev/null || { echo "bats is not installed (apt install bats / dnf install bats / pacman -S bats)"; exit 1; }
cd "$ROOT"
[ $# -eq 0 ] || exec bats "$@"
rc=0
bats tests/unit || rc=1
python3 -m unittest discover -s tests || rc=1
exit $rc
