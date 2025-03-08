#!/bin/bash

################################################################################
#
# This script runs Defects4j computation in parallel. It handles setup (excluding
# Defects4j-specific setup, which you should do from the README.md of this repo).
# The command should be run from the root directory of `defects4j-grt`.
#
################################################################################

# Function to prompt the user for confirmation
confirm_proceed() {
    while true; do
        read -p "Type 'y' to continue: " response
        case $response in
            [Yy]* )
                echo "Proceeding with the action."
                return 0  # Success, proceed with the action
                ;;
            [Nn]* )
                echo "Action aborted."
                return 1  # Exit or abort, action canceled
                ;;
            * )
                echo "Invalid input. Please type 'y' to proceed or 'n' to cancel."
                ;;
        esac
    done
}

# Warn about files removed
echo "Warning: This script will REMOVE all defects4j-grt/framework/test/test_d4j_* directories!"
echo "Are you sure you want to proceed? (y/n)"
if confirm_proceed; then
  echo "Running script..."
else
  exit 1
fi

# Setup java versions
# TODO how to set this up without sudo perms?

# Setup Defects4j
echo "START: Setting up defects4j-grt"

cpanm --installdeps .
./init.sh

cd ..
WORK_DIR=$(pwd)
export D4J_HOME=$WORK_DIR/"defects4j-grt"
export PATH=$PATH:$D4J_HOME/"framework/bin"
export randoop=$WORK_DIR/"randoop-grt"

defects4j info -p Lang
echo "SUCCESS: Set up defects4j-grt"

# Setup randoop-grt
echo "START: Setting up randoop-grt"

git clone git@github.com:edward-qin/randoop-grt.git
cd $randoop
rm -rf build/libs/
./gradlew assemble

# Link randoop-current.jar
cd $D4J_HOME/"framework/lib/test_generation/generation"
ln -s $randoop/"build/libs/randoop-all-4.3.3.jar" "randoop-current.jar"
echo "SUCCESS: Set up randoop-grt"

# Run grt generation in parallel
echo "START: Running Defect Detection Evaluation"

cd $D4J_HOME/"framework/test"
rm -rf "test_d4j_*"

./grt-eval-tab4-parallel.sh
echo "SUCCESS: Ran Defect Detection Evaluation"

# Create table with python file
echo "START: Generating Table IV from results"

python -m venv $D4J_HOME/".venv"
source $D4J_HOME/".venv/bin/activate"
pip install pandas

python generate_tab4.py
echo "SUCCESS: Generated Table IV from results"

exit 0