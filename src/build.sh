#!/bin/sh
# Builds the B-Tree Filer units and the example programs with Free Pascal.
#
# Usage:  ./build.sh [additional fpc options]
#
# Examples:
#   ./build.sh                 native build
#   ./build.sh -Twin64         cross build for 64 bit Windows
#
# The compiled units are written to ./units, the programs to ./bin.

cd "$(dirname "$0")" || exit 1
mkdir -p units bin

UNITS="basesupp filer numkeys reorg rebuild vrec vreorg vrebuild fixtovar
       iscompat vrcompat isamtool tpalloc msort tpcmd browser carrconv
       dbimpexp"
PROGRAMS="bigsort convert db2isam isam2db example netexamp traffic
          simpdemo netdemo"

for U in $UNITS; do
  fpc "$@" -FUunits -Fuunits "$U.pas" || exit 1
done
for P in $PROGRAMS; do
  fpc "$@" -FUunits -Fuunits -FEbin "$P.pas" || exit 1
done
echo "Build completed."
