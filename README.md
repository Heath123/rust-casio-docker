# rust-casio-docker

A Dockerfile for setting up rust_codegen_gcc for SuperH, which is useful for Casio calculators. After building use it like this (to generate a linkable object file):

`docker run --rm  -v <source directory>:/prog/ <image name> /usr/src/rustc_codegen_gcc/rustc.sh /prog/test.rs --emit=obj -o /prog/test.o --crate-type=lib -O`

This doesn't currently provide the `std` library so you have to use `#![no_std]`
