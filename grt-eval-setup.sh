#!/bin/bash

################################################################################
#
# This script sets up grt-eval.sh. It addresses java versioning and perl
# libraries. The command should be run from the root directory of `defects4j-grt`.
#
# Creates the following directory structure:
# ~ (your home directory)
# |- defects4j-grt
# |- java
#   |- jdk8u292-b10
#   |- jdk-11.0.9.1+1
# |- perl5
#
# Usage: Run this file once
#   ./grt-eval-setup.sh
#
################################################################################

BASHRC="$HOME/.bashrc"

# Setup java 8 and java 11: Replace with latest versions as needed
cd ~
wget https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u292-b10_openj9-0.26.0/OpenJDK8U-jdk_x64_linux_openj9_8u292b10_openj9-0.26.0.tar.gz
wget https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.9.1%2B1/OpenJDK11U-jdk_x64_linux_hotspot_11.0.9.1_1.tar.gz

mkdir ~/java
tar -xvzf OpenJDK8U-jdk_x64_linux_openj9_8u292b10_openj9-0.26.0.tar.gz -C ~/java
tar -xvzf OpenJDK11U-jdk_x64_linux_hotspot_11.0.9.1_1.tar.gz -C ~/java

ALIAS_LINES="
alias usejdk8='export JAVA_HOME=~/java/jdk8u292-b10 && export PATH=\$JAVA_HOME/bin:\$PATH'
alias usejdk11='export JAVA_HOME=~/java/jdk-11.0.9.1+1 && export PATH=\$JAVA_HOME/bin:\$PATH'
"
if ! grep -q "alias usejdk8=" "$BASHRC"; then
  echo "$ALIAS_LINES" >>"$BASHRC"
fi

# Setup perl library
cd defects4j-grt # or where your defects4j-grt directory is
cpanm --installdeps .
cpanm --local-lib=~/perl5 String::Interpolate

EXPORT_LINES="
export PERL5LIB=\$HOME/perl5/lib/perl5:\$PERL5LIB
export PATH=\$HOME/perl5/bin:\$PATH
"
if ! grep -q "export PERL5LIB=" "$BASHRC"; then
  echo "$EXPORT_LINES" >>"$BASHRC"
fi

source "$BASHRC"
