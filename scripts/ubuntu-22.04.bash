#!/usr/bin/sh
#
# Needed Ubuntu 22.04 packages for running the project
# NOTE: GTKWave should be built from source, as Ubuntu 22.04 packages a non-GHW
#       compatiable version of GTKWave.
#

apt install python3 ghdl gtkwave gcc-riscv64-unknown-elf

