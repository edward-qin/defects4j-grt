#!/bin/bash

# Define the command to run
CMD="./test_gen_tests.sh -p Chart -t 120"

# Use a loop to generate 10 instances of the command
seq 10 | parallel -j 10 "$CMD"

