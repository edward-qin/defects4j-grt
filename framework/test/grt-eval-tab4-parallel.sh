#!/bin/bash

# Define parameters
CLASSES=("Math" "Lang" "Time" "Chart")
GENERATORS=("evosuite" "randoop" "randoopDynamicTyping" "randoopInputConstruction" "randoopMinCostFirst" "randoopMinCoverageFirst" "randoopGRT")
TIMES=(120 300 600)

# Number of cluster nodes
NUM_NODES=48

# Create a list of tasks
TASKS=()
for class in "${CLASSES[@]}"; do
    for generator in "${GENERATORS[@]}"; do
        for time in "${TIMES[@]}"; do
            TASKS+=("$class $generator $time")
        done
    done
done

# Export function for parallel execution
run_task() {
    class=$1
    generator=$2
    time=$3
    echo "Running: ./grt-eval-tab4.sh -p $class -g $generator -t $time"
    ./grt-eval-tab4.sh -p "$class" -g "$generator" -t "$time"
}

export -f run_task

# Run tasks in parallel across nodes
printf "%s\n" "${TASKS[@]}" | parallel -j $NUM_NODES --colsep ' ' run_task
