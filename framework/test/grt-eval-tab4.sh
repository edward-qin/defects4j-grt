#!/usr/bin/env bash
################################################################################
#
# This script runs Defects4J defect detection on Randoop, GRT, and EvoSuite to
# replicate Table IV: Defect Detection in Defects4J Benchmarks in the original
# GRT Paper.
#
# The key difference with grt-eval-tab4-unit.sh is that this file does not have
# bug-level granularity. It runs ALL bugs for a given program, generator, and
# timeout.
#
# The output is a CSV file containing PASS/FAIL/BROKEN statuses of bugs,
# located at `test_d4j_<PID>_<TIMESTAMP>/result_db/bug_detection`
#
# Example:
#   * Generate for all programs, generators, times:       ./grt-eval-tab4.sh
#   * Generate for JFreeChart, all generators, times:     ./grt-eval-tab4.sh -pChart
#   * Generate for all programs, EvoSuite, all times:     ./grt-eval-tab4.sh -gevosuite
#   * Generate for all programs, generators, 120 seconds: ./grt-eval-tab4.sh -t120
#
################################################################################

# Import helper subroutines and variables, and init Defects4J
HERE="$(cd "$(dirname "$0")" && pwd)" || {
    echo "cannot cd to $(dirname "$0")"
    exit 2
}
source "$HERE/test.include" || exit 1
source "$HERE/grt-eval-tab4-common.sh"
init

# Print usage message and exit
usage() {
    local known_pids
    known_pids=$(defects4j pids)
    echo "usage: $0 [-p <project id>] [-g <generator>] [-t <timeout in sec>]"
    echo "Project ids:"
    for pid in $known_pids; do
        if [[ " ${CLASSES[@]} " =~ " $pid " ]]; then
            echo "  * $pid"
        fi
    done
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
while getopts ":p:g:t:" opt; do
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

if [[ -n "$PID" && ! -e "$BASE_DIR/framework/core/Project/$PID.pm" ]]; then
    usage
fi

if [[ -n "$PID" && ! " ${CLASSES[@]} " =~ " $PID " ]]; then
    usage
elif [[ -n "$PID" ]]; then
    CLASSES=("$PID")
fi

if [[ -n "$GENERATOR" && ! " ${GENERATORS[@]} " =~ " $GENERATOR " ]]; then
    usage
elif [[ -n "$GENERATOR" ]]; then
    GENERATORS=("$GENERATOR")
fi

if [[ -n "$TIMEOUT" && ! " ${TIMES[@]} " =~ " $TIMEOUT " ]]; then
    usage
elif [[ -n "$TIMEOUT" ]]; then
    TIMES=($TIMEOUT)
fi

echo "Using programs: ${CLASSES[@]}"
echo "Using generators: ${GENERATORS[@]}"
echo "Using times: ${TIMES[@]}"

usejdk11

script_name_without_sh=${script//.sh/}
mkdir -p "$TEST_DIR/log"

################################################################################
# Run all specified generators on the specified programs with specified timeout
################################################################################

# Reproduce all bugs (and log all results), regardless of whether errors occur
HALT_ON_ERROR=0

work_dir="$TMP_DIR/$PID"
mkdir -p "$work_dir"

# Clean working directory
rm -rf "${work_dir:?}/*"

# Iterate over each generator, each project, each bug, each timeout
for generator in ${GENERATORS[@]}; do
    for pid in ${CLASSES[@]}; do
        BUGS="$(get_bug_ids "$BASE_DIR/framework/projects/$pid/$BUGS_CSV_ACTIVE")"
        for bid in $BUGS; do
            # Skip all bug ids that do not exist in the active-bugs csv
            if ! grep -q "^$bid," "$BASE_DIR/framework/projects/$pid/$BUGS_CSV_ACTIVE"; then
                warn "Skipping bug ID that is not listed in active-bugs csv: $pid-$bid"
                continue
            fi
            for time in ${TIMES[@]}; do
                LOG="$TEST_DIR/log/${script_name_without_sh}$(printf '_%s_%s_%s_%s' "$PID" "$GENERATOR" "$TIMEOUT" $$).log"

                # Use the modified classes as target classes for efficiency
                target_classes="$BASE_DIR/framework/projects/$pid/modified_classes/$bid.src"

                # Directory for generated test suites
                suite_num=1
                suite_dir="$work_dir/$generator/$suite_num"

                # Generate (regression) tests for the fixed version
                vid=${bid}f

                # Run generator and the fix script on the generated test suite
                echo "Running test generation on $generator for program $pid-$vid and timeout $time seconds"
                if ! gen_tests.pl -g "$generator" -p "$pid" -v "$vid" -n 1 -o "$TMP_DIR" -b "$time" -c "$target_classes"; then
                    die "run $generator (regression) on $pid-$vid with timeout $time"
                    # Skip any remaining analyses (cannot be run), even if halt-on-error is false
                    continue
                fi
                fix_test_suite.pl -p "$pid" -d "$suite_dir" || die "fix test suite"

                # Run test suite and determine bug detection
                run_bug_detection "$pid" "$suite_dir" "$time"

                rm -rf "${work_dir:?}/$generator"
            done
        done
    done
done

HALT_ON_ERROR=1

# Print a summary of what went wrong
if [ $ERROR != 0 ]; then
    printf '=%.s' $(seq 1 80) 1>&2
    echo "Please check the $TEST_DIR/log/grt-eval-tab4_<Program>_<Generator>_<Timeout>_PID.log files"
fi

# Indicate whether an error occurred
exit $ERROR
