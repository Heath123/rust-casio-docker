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

# Download rustc_codegen_gcc
WORKDIR /usr/src/
RUN git clone https://github.com/rust-lang/rustc_codegen_gcc --depth 1 --single-branch

# Patch rustc_codegen_gcc
WORKDIR /usr/src/rustc_codegen_gcc/

COPY config.patch ../config.patch
RUN patch -t -p1 < ../config.patch

COPY set_superh_flags.patch ..
RUN patch -t -p1 < ../set_superh_flags.patch

COPY ptr_size_fix.patch ..
RUN patch -t -p1 < ../ptr_size_fix.patch

COPY disable_stdlib.patch ..
RUN patch -t -p1 < ../disable_stdlib.patch

# Get LLVM just for the compiler-rt part
# TODO: Can this be skipped if using libgcc?
WORKDIR /usr/src/
# Do a sparse checkout to save disk space and download time
# https://stackoverflow.com/a/52269934/4012708
RUN git clone -n --depth=1 --single-branch --filter=tree:0 https://github.com/llvm/llvm-project llvm
WORKDIR /usr/src/llvm/
RUN git sparse-checkout set --no-cone compiler-rt
RUN git checkout

# Horrible hack: for some reason it tries to use the default as assembler so make that a symlink
RUN ln -s /usr/local/cross/bin/sh3eb-elf-as /usr/local/bin/as

# Horrible hack 2: it expects to use the mips-linux-gnu-gcc compiler so symlink that too
RUN ln -s /usr/local/cross/bin/sh3eb-elf-gcc /usr/local/bin/mips-linux-gnu-gcc

# Compile rustc_codegen_gcc
WORKDIR /usr/src/rustc_codegen_gcc/
ENV RUST_COMPILER_RT_ROOT="/usr/src/llvm/compiler-rt"
RUN echo /usr/local/cross/lib/ > gcc_path
RUN ./prepare_build.sh
RUN LIBRARY_PATH=$(cat gcc_path) LD_LIBRARY_PATH=$(cat gcc_path) PATH=/usr/local/bin/:$PATH:/usr/local/bin/ ./build.sh --release

COPY rustc.sh .
