#!/bin/sh
# Builds the vasm 68000 assembler (Motorola syntax) into .tools/vasm/.
# Tries the official release tarball first, then a public git mirror.
# Needs: a C compiler, make, and curl or git.
set -e
DEST="${1:-.tools}"
BIN="$DEST/vasm/vasmm68k_mot"
if [ -x "$BIN" ]; then
    echo "vasm already built: $BIN"
    exit 0
fi
mkdir -p "$DEST"
cd "$DEST"
rm -rf vasm vasm.tar.gz
if curl -fsSL --max-time 60 -o vasm.tar.gz http://sun.hasenbraten.de/vasm/release/vasm.tar.gz \
   && tar xzf vasm.tar.gz; then
    echo "vasm: official release tarball"
else
    rm -rf vasm vasm.tar.gz
    echo "vasm: official site unreachable, using the git mirror"
    git clone --depth 1 https://github.com/StarWolf3000/vasm-mirror vasm
fi
make -C vasm CPU=m68k SYNTAX=mot >/dev/null
echo "vasm built: $DEST/vasm/vasmm68k_mot"
