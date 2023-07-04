#!/usr/bin/env bash

shopt -s extglob

UNIT_TEST_GLOB="../../riscv-tests/isa/rv32ui-p-!(*.dump)"
ELF2HEX="../../elf2hex/elf2hex"

FILES=( ${UNIT_TEST_GLOB[@]} )
for file in "${FILES[@]}"; do
    name=$(basename "$file")
    echo "${name}"
    "${ELF2HEX}" --bit-width 32 --input "${file}" --output "${name}.text_hex_dump"
done
