#!/bin/bash

################################################################################
#
# This script runs grt-eval-tab4.sh in parallel on the Cartesian product of
# CLASSES, GENERATORS, and TIMES defined below.
#
# The degree of parallelism is hard-coded as NUM_CORES. Modify this as needed.
#
################################################################################


# Define parameters
CLASSES=("Math" "Lang" "Time" "Chart")
GENERATORS=("evosuite" "randoop" "randoopGRTMinusDynamicTyping" "randoopGRTMinusMinCostFirst" "randoopGRTMinusMinCoverageFirst" "randoopGRT")
TIMES=(120 300 600)

# Number of compute cores
# NUM_CORES=$(($(nproc) / 2))
NUM_CORES=$(( $(nproc) - 4 ))
echo "Running on at most $NUM_CORES concurrent processes"
HERE="$(cd "$(dirname "$0")" && pwd)" || { echo "cannot cd to $(dirname "$0")"; exit 2; }
source "$HERE/test.include" || exit 1

# Create a list of tasks
TASKS=()
for class in "${CLASSES[@]}"; do
    BUGS="$(get_bug_ids "$BASE_DIR/framework/projects/$class/$BUGS_CSV_ACTIVE")"
    echo "BUGS: ${BUGS[@]}"

    for generator in "${GENERATORS[@]}"; do
        for time in "${TIMES[@]}"; do
            for bug in $BUGS; do
                TASKS+=("$class $generator $time $bug")
            done
        done
    done
done

# Export function for parallel execution
run_task() {
    class=$1
    generator=$2
    time=$3
    bug=$4
    echo "Running: ./grt-eval-tab4.sh -p $class -g $generator -t $time -b $bug"
    ./grt-eval-tab4-unit.sh -p "$class" -g "$generator" -t "$time" -b "$bug"
}

export -f run_task

# Run tasks in parallel across nodes
printf "%s\n" "${TASKS[@]}" | parallel -j $NUM_CORES --colsep ' ' run_task
