#!/bin/bash
PATH="${PWD}/thirdparty/lib/linuxbsd/x86_64/bin:$PATH"
# Helper script to build schemas for MSEP.one
for file in *.capnp; do
  capnp compile -o/root/capnproto/lib/linuxbsd/x86_64/bin/capnpc-c++ "$file"
done
