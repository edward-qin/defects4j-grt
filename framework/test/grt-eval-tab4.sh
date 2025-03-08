#!/usr/bin/env bash
################################################################################
#
# This script runs Defects4J defect detection on Randoop, GRT, and EvoSuite to
# replicate Table IV: Defect Detection in Defects4J Benchmarks in the original
# GRT Paper
# The output is a CSV file containing PASS/FAIL/BROKEN statuses of bugs
#
# Example:
#   * Generate for all programs, generators, times:       ./grt-eval-tab4.sh
#   * Generate for JFreeChart, all generators, times:     ./grt-eval-tab4.sh -pChart
#   * Generate for all programs, EvoSuite, all times:     ./grt-eval-tab4.sh -gevosuite
#   * Generate for all programs, generators, 120 seconds: ./grt-eval-tab4.sh -t120
#
################################################################################

# Dimensions in GRT paper
PROGRAMS=("Chart" "Math" "Time" "Lang")
TEST_GENERATORS=("evosuite" "randoop" "randoopDynamicTyping" "randoopInputConstruction" "randoopMinCostFirst" "randoopMinCoverageFirst" "randoopGRT")
TIMES=(120 300 600)

# Import helper subroutines and variables, and init Defects4J
HERE="$(cd "$(dirname "$0")" && pwd)" || { echo "cannot cd to $(dirname "$0")"; exit 2; }
source "$HERE/test.include" || exit 1
init

# Print usage message and exit
usage() {
    local known_pids; known_pids=$(defects4j pids)
    echo "usage: $0 [-p <project id>] [-g <generator>] [-t <timeout in sec>]"
    echo "Project ids:"
    for pid in $known_pids; do
        if [[ " ${PROGRAMS[@]} " =~ " $pid " ]]; then
            echo "  * $pid"
        fi
    done
    echo "Test generators:"
    for generator in ${TEST_GENERATORS[@]}; do
        echo "  * $generator"
    done
    echo "Timeouts:"
    for time in ${TIMES[@]}; do
        echo "  * $time"
    done
    exit 1
}

usejdk8() {
  export JAVA_HOME=/usr/lib/jvm/java-8-openjdk
  export PATH=$JAVA_HOME/bin:$PATH
  echo "Switched to JDK 8: $JAVA_HOME"
}

usejdk11() {
  export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
  export PATH=$JAVA_HOME/bin:$PATH
  echo "Switched to JDK 11: $JAVA_HOME"
}

# Check arguments
while getopts ":p:g:t:" opt; do
    case $opt in
        p) PID="$OPTARG"
            ;;
        g) GENERATOR="$OPTARG"
            ;;
        t) if [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
                TIMEOUT=$((OPTARG))  # Convert to integer
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

if [[ -n "$PID" && ! " ${PROGRAMS[@]} " =~ " $PID " ]]; then
    usage
elif [[ -n "$PID" ]]; then
    PROGRAMS=("$PID")
fi

if [[ -n "$GENERATOR" && ! " ${TEST_GENERATORS[@]} " =~ " $GENERATOR " ]]; then
    usage
elif [[ -n "$GENERATOR" ]]; then
    TEST_GENERATORS=("$GENERATOR")
fi

if [[ -n "$TIMEOUT" && ! " ${TIMES[@]} " =~ " $TIMEOUT " ]]; then
    usage
elif [[ -n "$TIMEOUT" ]]; then
    TIMES=($TIMEOUT)
fi

echo "Using programs: ${PROGRAMS[@]}"
echo "Using generators: ${TEST_GENERATORS[@]}"
echo "Using times: ${TIMES[@]}"

init
usejdk11

# Create log file
script_name_without_sh=${script//.sh/}
LOG="$TEST_DIR/${script_name_without_sh}$(printf '_%s_%s' "$PID" $$).log"

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
for generator in ${TEST_GENERATORS[@]}; do
    for pid in ${PROGRAMS[@]}; do
        BUGS="$(get_bug_ids "$BASE_DIR/framework/projects/$pid/$BUGS_CSV_ACTIVE")"
        for bid in $BUGS ; do
            # Skip all bug ids that do not exist in the active-bugs csv
            if ! grep -q "^$bid," "$BASE_DIR/framework/projects/$pid/$BUGS_CSV_ACTIVE"; then
                warn "Skipping bug ID that is not listed in active-bugs csv: $pid-$bid"
                continue
            fi
            for time in ${TIMES[@]}; do
                # Use the modified classes as target classes for efficiency
                target_classes="$BASE_DIR/framework/projects/$pid/modified_classes/$bid.src"

                # Directory for generated test suites
                suite_num=1
                suite_dir="$work_dir/$generator/$suite_num"

                # Generate (regression) tests for the fixed version
                vid=${bid}f

                # Run generator and the fix script on the generated test suite
                echo "Running test generation on $generator for program $pid-$vid and timeout $time seconds"
                if ! gen_tests.pl -g "$generator" -p "$pid" -v "$vid" -n 1 -o "$TMP_DIR" -b "$time" -c "$target_classes";
                then
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
    echo 1>&2
    echo "The following errors occurred:" 1>&2
    cat "$LOG" 1>&2
fi

# Indicate whether an error occurred
exit $ERROR
