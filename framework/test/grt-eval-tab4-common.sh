#!/bin/bash

################################################################################
#
# This script holds common configurations for grt-eval-tab4-*.sh scripts
#  - CLASSES, GENERATORS, TIMES configs
#  - usejdk* functions for switching between JDKs
#
################################################################################

# Define Defects4j configurations
CLASSES=("Math" "Lang" "Time" "Chart")
GENERATORS=(
  "evosuite"
  "randoop"
  "randoopGRTMinusDynamicTyping"
  "randoopGRTMinusMinCostFirst"
  "randoopGRTMinusMinCoverageFirst"
  # "randoopGRTMinusInputConstruction"
  # "randoopGRTMinusInputFuzzing"
  # "randoopGRTMinusConstantMining"
  "randoopGRT"
)
TIMES=(120 300 600)

# Switch to correct JDK
# Assumption: the java versions have been installed (with the same version)
# If you have a different java version, modify these functions correspondingly
usejdk8() {
  export JAVA_HOME=~/java/jdk8u292-b10
  export PATH=$JAVA_HOME/bin:$PATH
  echo "Switched to JDK 8: $JAVA_HOME"
}

usejdk11() {
  export JAVA_HOME=~/java/jdk-11.0.9.1+1
  export PATH=$JAVA_HOME/bin:$PATH
  echo "Switched to JDK 11: $JAVA_HOME"
}

export CLASSES GENERATORS TIMES
export -f usejdk8 usejdk11
