#!/usr/bin/env bash
################################################################################
#
# This script runs Defects4J defect detection on Randoop, GRT, and EvoSuite to
# replicate Table IV: Defect Detection in Defects4J Benchmarks in the original
# GRT Paper.
#
# The key difference with grt-eval-tab4.sh is that this file accepts an
# additional -b argument for the bug ID.
#
# The output is a CSV file containing PASS/FAIL/BROKEN statuses of bugs,
# located at `test_d4j_<PID>_<TIMESTAMP>/result_db/bug_detection`
#
# Example:
#   * Generate for JFreeChart, EvoSuite, 120 seconds, Bug 1
#     ./grt-eval-tab4.sh -pChart -gevosuite -t120 -b1
#   * Obtain bug ids with
#     get_bug_ids "$BASE_DIR/framework/projects/$pid/$BUGS_CSV_ACTIVE"
################################################################################

# Import helper subroutines and variables, and init Defects4J
HERE="$(cd "$(dirname "$0")" && pwd)" || {
    echo "cannot cd to $(dirname "$0")"
    exit 2
}
source "$HERE/test.include" || exit 1
source "$HERE/grt-eval-tab4-common.sh"
init

usejdk11

# Print usage message and exit
usage() {
    local known_pids
    known_pids=$(defects4j pids)
    echo "usage: $0 [-p <project id>] [-g <generator>] [-t <timeout in sec>]"
    echo "Project ids:"
    for pid in ${CLASSES[@]}; do
        echo "  * $pid"
    done
    if [[ -n "$PID" && "$BASE_DIR/framework/projects/$PID/$BUGS_CSV_ACTIVE" ]]; then
        echo "Bug ids:"
        BUGS="$(get_bug_ids "$BASE_DIR/framework/projects/$pid/$BUGS_CSV_ACTIVE")"
        for bid in ${BUGS[@]}; do
            echo "  * $bid"
        done
    fi
    echo "Test generators:"
    for generator in ${GENERATORS[@]}; do
        echo "  * $generator"
    done
    echo "Timeouts:"
    for time in ${TIMES[@]}; do
        echo "  * $time"
    done
    exit 1
}

# Check arguments
while getopts ":p:g:t:b:" opt; do
    case $opt in
    p)
        PID="$OPTARG"
        ;;
    g)
        GENERATOR="$OPTARG"
        ;;
    t)
        if [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
            TIMEOUT=$((OPTARG)) # Convert to integer
        else
            echo "Invalid timeout value: $OPTARG. Must be a positive integer." >&2
            usage
        fi
        ;;
    b)
        BID="$OPTARG"
        ;;
    \?)
        echo "Unknown option: -$OPTARG" >&2
        usage
        ;;
    :)
        echo "No argument provided: -$OPTARG." >&2
        usage
        ;;
    esac
done

if [[ ! -e "$BASE_DIR/framework/core/Project/$PID.pm" ]]; then
    echo "HELLO"
fi

if [[ -n "$PID" && ! -e "$BASE_DIR/framework/core/Project/$PID.pm" ]]; then
    usage
fi

if [[ -z "$PID" || ! " ${CLASSES[@]} " =~ " $PID " ]]; then
    usage
fi

if [[ -z "$GENERATOR" || ! " ${GENERATORS[@]} " =~ " $GENERATOR " ]]; then
    usage
fi

if [[ -z "$TIMEOUT" || ! " ${TIMES[@]} " =~ " $TIMEOUT " ]]; then
    usage
fi

if ! grep -q "^$BID," "$BASE_DIR/framework/projects/$PID/$BUGS_CSV_ACTIVE"; then
    usage
fi

echo "Using programs: $PID"
echo "Using generators: $GENERATOR"
echo "Using times: $TIMEOUT"
echo "Using bug: $BID"

script_name_without_sh=${script//.sh/}
mkdir -p "$TEST_DIR/log"

################################################################################
# Run specified generator on the specified program with specified timeout
################################################################################

# Reproduce all bugs (and log all results), regardless of whether errors occur
HALT_ON_ERROR=0

work_dir="$TMP_DIR/$PID"
mkdir -p "$work_dir"

# Clean working directory
rm -rf "${work_dir:?}/*"

# Iterate over each generator, each project, each bug, each timeout
LOG="$TEST_DIR/log/${script_name_without_sh}$(printf '_%s_%s_%s_%s' "$PID" "$GENERATOR" "$TIMEOUT" $$).log"

# Use the modified classes as target classes for efficiency
target_classes="$BASE_DIR/framework/projects/$PID/modified_classes/$BID.src"

# Directory for generated test suites
suite_num=1
suite_dir="$work_dir/$GENERATOR/$suite_num"

# Generate (regression) tests for the fixed version
vid=${BID}f

# Run generator and the fix script on the generated test suite
echo "Running test generation on $GENERATOR for program $PID-$BID and timeout $TIMEOUT seconds"
if ! gen_tests.pl -g "$GENERATOR" -p "$PID" -v "$vid" -n 1 -o "$TMP_DIR" -b "$TIMEOUT" -c "$target_classes"; then
    die "run $GENERATOR (regression) on $PID-$vid with timeout $TIMEOUT"
    # Skip any remaining analyses (cannot be run), even if halt-on-error is false
    continue
fi
fix_test_suite.pl -p "$PID" -d "$suite_dir" || die "fix test suite"

# Run test suite and determine bug detection
run_bug_detection "$PID" "$suite_dir" "$TIMEOUT"

rm -rf "${work_dir:?}/$GENERATOR"

HALT_ON_ERROR=1

# Print a summary of what went wrong
if [ $ERROR != 0 ]; then
    printf '=%.s' $(seq 1 80) 1>&2
    echo "Please check the TEST_DIR/log/grt-eval-tab4_<Program>_<Generator>_<Timeout>_PID.log files"
fi

# Indicate whether an error occurred
exit $ERROR
