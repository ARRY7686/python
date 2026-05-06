#!/usr/bin/env bash
# test.sh — Mars challenge runner for kubernetes/watch stream chunk parser
#
# Usage:
#   ./test.sh --output_path results.xml base
#   ./test.sh --output_path results.xml new
#
# base: existing regression suite (watch_test.py) — must PASS on original state
# new:  new chunk-boundary tests (watch_stream_test.py) — must FAIL before
#       solution.patch is applied, PASS after

set -euo pipefail

OUTPUT_PATH=""
MODE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output_path) OUTPUT_PATH="$2"; shift 2 ;;
        base|new)      MODE="$1"; shift ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$MODE" || -z "$OUTPUT_PATH" ]]; then
    echo "Usage: $0 --output_path <path> <base|new>" >&2
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PYTHON="${PYTHON:-python3}"
if [[ -x "/workspace/venv/bin/python" ]]; then
    PYTHON="/workspace/venv/bin/python"
fi

case "$MODE" in
    base)
        TARGET="$REPO_ROOT/kubernetes/base/watch/watch_test.py"
        SUITE="watch_regression"
        ;;
    new)
        TARGET="$REPO_ROOT/kubernetes/base/watch/watch_shipd_stream_test.py"
        SUITE="watch_stream_chunk_tests"
        ;;
    *)
        echo "Unknown mode: $MODE" >&2; exit 1 ;;
esac

set +e
"$PYTHON" -m pytest \
    "$TARGET" \
    --tb=short \
    -v \
    "--junitxml=${OUTPUT_PATH}" \
    "-o" "junit_suite_name=${SUITE}"
EXIT_CODE=$?
set -e

exit $EXIT_CODE
