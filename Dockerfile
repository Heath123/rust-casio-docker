FROM rustlang/rust:nightly

# Install dependencies
RUN apt update
RUN apt install -y texinfo libgmp3-dev libmpc-dev libmpfr-dev bison flex

# Download binutils
WORKDIR /usr/src/
RUN wget https://ftp.gnu.org/gnu/binutils/binutils-2.40.tar.gz
RUN tar -xzf binutils-2.40.tar.gz
RUN mv binutils-2.40 binutils

# Install binutils
WORKDIR /usr/src/build-binutils
RUN mkdir -p /usr/local/cross
ENV PATH="${PATH}:/usr/local/cross/bin/"
RUN ../binutils/configure --target=sh3eb-elf --prefix=/usr/local/cross --disable-nls
RUN make -j$(nproc)
RUN make install

# Download gcc
WORKDIR /usr/src/
RUN git clone https://github.com/antoyo/gcc --depth 1 --single-branch

# Patch GCC
COPY bfloat_fix.patch bfloat_fix.patch
WORKDIR /usr/src/gcc/
RUN patch -t -p1 < ../bfloat_fix.patch
WORKDIR /usr/src/

# Compile GCC
WORKDIR /usr/src/build-gcc
RUN ../gcc/./configure --target=sh3eb-elf --prefix=/usr/local/cross --disable-nls --enable-languages=c,jit,c++ --without-headers --enable-host-shared --disable-bootstrap
RUN make all-gcc -j$(nproc)
RUN make install-gcc

# Compile libgcc
WORKDIR /usr/src/build-gcc
RUN make all-target-libgcc -j$(nproc)
RUN make install-target-libgcc

# Download rustc_codegen_gcc
WORKDIR /usr/src/
RUN git clone https://github.com/rust-lang/rustc_codegen_gcc --depth 1 --single-branch

# Get LLVM just for the compiler-rt part
# TODO: Can this be skipped if using libgcc?
WORKDIR /usr/src/
# Do a sparse checkout to save disk space and download time
# https://stackoverflow.com/a/52269934/4012708
RUN git clone -n --depth=1 --single-branch --filter=tree:0 https://github.com/llvm/llvm-project llvm
WORKDIR /usr/src/llvm/
RUN git sparse-checkout set --no-cone compiler-rt
RUN git checkout

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

# Compile rustc_codegen_gcc
WORKDIR /usr/src/rustc_codegen_gcc/
ENV RUST_COMPILER_RT_ROOT="/usr/src/llvm/compiler-rt"
RUN echo /usr/local/cross/lib/ > gcc_path
RUN ./prepare_build.sh
RUN LIBRARY_PATH=$(cat gcc_path) LD_LIBRARY_PATH=$(cat gcc_path) PATH=/usr/local/bin/:$PATH:/usr/local/bin/ ./build.sh --release

COPY rustc.sh .
