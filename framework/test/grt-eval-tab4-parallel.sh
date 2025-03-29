#!/bin/bash

################################################################################
#
# This script runs grt-eval-tab4.sh in parallel on the Cartesian product of
# CLASSES, GENERATORS, and TIMES defined in grt-eval-tab4-common.sh
#
# The degree of parallelism is hard-coded as NUM_THREADS. Modify this as needed.
#
################################################################################

# Max number of threads
NUM_THREADS=$(($(nproc) - 4))
echo "Running on at most $NUM_THREADS concurrent processes"

HERE="$(cd "$(dirname "$0")" && pwd)" || {
    echo "cannot cd to $(dirname "$0")"
    exit 2
}
source "$HERE/test.include" || exit 1
echo "Sourced test.include"

source "$HERE/grt-eval-tab4-common.sh" || exit 1
echo "Running grt-eval-tab4 in parallel on configurations:"
for var in CLASSES GENERATORS TIMES; do
    echo "$var = ${!var[@]}"
done

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
printf "%s\n" "${TASKS[@]}" | parallel -j $NUM_THREADS --colsep ' ' run_task
