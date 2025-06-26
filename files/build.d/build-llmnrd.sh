#!/bin/sh
# build llmnrd for distros that don't have it
set -e

mkdir -p /tmp/llmnrd
# llmnrd v 0.7(Sep 14 2020)
download https://github.com/tklauser/llmnrd/archive/refs/tags/v0.7.tar.gz > /tmp/llmnrd.tar.gz
tar xf /tmp/llmnrd.tar.gz --strip-components=1 -C /tmp/llmnrd
cd /tmp/llmnrd
gcc -static -o /usr/bin/llmnrd -DVERSION_STRING="\"v`egrep '^VERSION = ' Makefile | sed 's/.*= //'`\"" -DGIT_VERSION='""' -DPIDFILE='"/run/llmnrd.pid"' llmnr.c iface.c socket.c util.c log.c llmnrd.c
