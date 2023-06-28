#!/bin/bash

# Script mostly by GPT-4
# Changes arguments that are MIPS elf files to SuperH
# This is because Rust generates ELF files with no code
# Rust thinks it's compiling for MIPS which it's not

# Function to change the ELF header of MIPS object file to a SuperH one
change_header() {
  local filepath="$1"
  printf '\x2A' | dd conv=notrunc of="$filepath" bs=1 seek=19
}

# Main script
wrapped_linker="sh-elf-gcc"

processed_args=()
for arg in "$@"; do
  if [[ "$arg" == *.o ]]; then
    if [ -f "$arg" ]; then
      mips_magic=$(dd if="$arg" bs=1 skip=18 count=2 2>/dev/null | od -t x1 -An | tr -d ' ')
      if [ "$mips_magic" == "0008" ]; then
        change_header "$arg"
      fi
    fi
  fi
  processed_args+=("$arg")
done

$wrapped_linker "${processed_args[@]}"

