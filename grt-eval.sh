#!/bin/bash

################################################################################
#
# This script runs Defects4j computation in parallel. It handles setup (excluding
# Defects4j-specific setup, which you should do from the README.md of this repo).
# The computation involves:
#  * Setting up defects4j-grt
#  * Running D4J computations in parallel with ./grt-eval-tab4-parallel.sh
#  * Generating Table 4 in defects4j-grt/framework/test/grt_table4.csv
# The command should be run from the root directory of `defects4j-grt`.
#
# Creates and uses the following directory structure:
# ~ (your home directory)
# |- defects4j-grt
#   |- .venv/
#   |- framework
#     |- test
#        |- test_d4j_<pid>_<timestamp>/result_db/bug_detection
#        |- grt_table4.csv
# |- randoop-grt
#
# Use ./grt-eval.sh --ignore-warning to bypass the user check
# This can be useful when making this a background process.
#
# Example:
#  * ./grt-eval.sh
#       Run normally from shell
#  * nohup ./grt-eval.sh --ignore-warning & disown
#       Run the script in parallel, detached from shell process
#
# If there are java versions or perl libraries missing, see grt-eval-setup.sh.
#
################################################################################

HERE="$(cd "$(dirname "$0")" && pwd)" || {
    echo "cannot cd to $(dirname "$0")"
    exit 2
}
source "$HERE/framework/test/grt-eval-tab4-common.sh"

# Function to prompt the user for confirmation
confirm_proceed() {
    while true; do
        read -p "Type 'y' to continue: " response
        case $response in
        [Yy]*)
            echo "Proceeding with the action."
            return 0 # Success, proceed with the action
            ;;
        [Nn]*)
            echo "Action aborted."
            return 1 # Exit or abort, action canceled
            ;;
        *)
            echo "Invalid input. Please type 'y' to proceed or 'n' to cancel."
            ;;
        esac
    done
}

# Warn about files removed
echo "Warning: This script will REMOVE all defects4j-grt/framework/test/[test_d4j_*|*.log] directories and files!"
echo "Are you sure you want to proceed? (y/n)"
if [[ "$1" == "--ignore-warning" ]] || confirm_proceed; then
    echo "Running script..."
else
    exit 1
fi

# Setup Defects4j
echo "START: Setting up defects4j-grt"

cpanm --installdeps .
./init.sh

cd ..
WORK_DIR=$(pwd)
export D4J_HOME=$WORK_DIR/"defects4j-grt"
export PATH=$PATH:$D4J_HOME/"framework/bin"
export randoop=$WORK_DIR/"randoop-grt"

usejdk11
defects4j info -p Lang
echo "SUCCESS: Set up defects4j-grt"

# Setup randoop-grt
echo "START: Setting up randoop-grt"

if [ ! -d "randoop-grt" ]; then
    git clone git@github.com:edward-qin/randoop-grt.git randoop-grt
fi
cd $randoop
rm -rf build/libs/
./gradlew assemble

# Link randoop-current.jar
cd $D4J_HOME/"framework/lib/test_generation/generation"
ln -sf $randoop/"build/libs/randoop-all-4.3.3.jar" "randoop-current.jar"
echo "SUCCESS: Set up randoop-grt"

# Run grt generation in parallel
echo "START: Running Defect Detection Evaluation"

cd $D4J_HOME/"framework/test"
rm -rf test_d4j_*
mkdir -p "log"
rm log/*.log
rm *.log

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
