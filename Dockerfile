FROM rustlang/rust:nightly

# Install dependencies
RUN apt-get update
RUN apt-get install -y texinfo libgmp3-dev libmpc-dev libmpfr-dev bison flex cmake
# TODO: Try to prune these down a bit
RUN apt-get install python3-pil libusb-1.0-0-dev libudev-dev libsdl2-dev libpng-dev libudisks2-dev libglib2.0-dev libppl-dev -y

# Install 
# TODO: Fix giteapc and everything installed with it to a specific commit for reproducability
ENV PATH="/root/.local/bin:$PATH"
WORKDIR /tmp/giteapc-install
RUN curl "https://gitea.planet-casio.com/Lephenixnoir/GiteaPC/archive/master.tar.gz" -o giteapc-master.tar.gz
RUN tar -xzf giteapc-master.tar.gz
WORKDIR /tmp/giteapc-install/giteapc
RUN python3 giteapc.py install Lephenixnoir/GiteaPC -y

# Install the C/C++ SDK and compiler
RUN giteapc install Lephenixnoir/fxsdk:noudisks2 Lephenixnoir/sh-elf-binutils -y
RUN giteapc install Lephenixnoir/sh-elf-gcc@rustc-codegen:clean -y
# Install libm and libc, then go back to the cimpiler for libstdc++
RUN giteapc install Lephenixnoir/OpenLibm Vhex-Kernel-Core/fxlibc Lephenixnoir/sh-elf-gcc -y
# Now get gint
RUN giteapc install Lephenixnoir/gint -y

# Get LLVM just for the compiler-rt part
# TODO: Can this be skipped if using libgcc?
# Also TODO: Try to fix it to a specific commit for reproducability
WORKDIR /usr/src/
# Do a sparse checkout to save disk space and download time
# https://stackoverflow.com/a/52269934/4012708
RUN git clone -n --depth=1 --single-branch --filter=tree:0 https://github.com/llvm/llvm-project llvm
WORKDIR /usr/src/llvm/
RUN git sparse-checkout set --no-cone compiler-rt
RUN git checkout

# Download rustc_codegen_gcc
WORKDIR /usr/src/
RUN wget -O rustc_codegen_gcc.zip https://github.com/rust-lang/rustc_codegen_gcc/archive/1bbee3e217d75e7bc3bfe5d8c1b35e776fce96e6.zip
RUN unzip rustc_codegen_gcc.zip
RUN rm rustc_codegen_gcc.zip
RUN mv rustc_codegen_gcc-* rustc_codegen_gcc

# Patch rustc_codegen_gcc
WORKDIR /usr/src/rustc_codegen_gcc/

COPY sh3eb-elf.json .

COPY config.patch ..
RUN patch -t -p1 < ../config.patch

COPY use_target_json.patch ..
RUN patch -t -p1 < ../use_target_json.patch

COPY cargo_release_by_default.patch ..
RUN patch -t -p1 < ../cargo_release_by_default.patch

COPY set_superh_flags.patch ..
RUN patch -t -p1 < ../set_superh_flags.patch

COPY ptr_size_fix.patch ..
RUN patch -t -p1 < ../ptr_size_fix.patch

COPY disable_stdlib.patch ..
RUN patch -t -p1 < ../disable_stdlib.patch

# # Install a wrapper script to fix an issue where Rust tries to link MIPS object files
COPY sh-link-wrap.sh /usr/local/bin/sh-link-wrap
RUN chmod +x /usr/local/bin/sh-link-wrap

# Compile rustc_codegen_gcc
WORKDIR /usr/src/rustc_codegen_gcc/
ENV RUST_COMPILER_RT_ROOT="/usr/src/llvm/compiler-rt"
RUN echo /root/.local/share/fxsdk/sysroot/lib/ > gcc_path
RUN ./prepare_build.sh
RUN LIBRARY_PATH=$(cat gcc_path) LD_LIBRARY_PATH=$(cat gcc_path) PATH=/usr/local/bin/:$PATH:/usr/local/bin/ ./build.sh --release

COPY rustc.sh .
