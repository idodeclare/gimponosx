#!/bin/sh

# set up temp SYMROOT
SYMROOT=$(perl -e 'use File::Temp qw(tempdir);
        $t=tempdir("/tmp/gimponosx.XXXXX") or exit(1);
        print $t') || exit 1
trap 'rm -rf "$SYMROOT"' EXIT

xcodebuild -configuration Release -project GimpOnOSX/GimpOnOSX.xcodeproj \
  SYMROOT="$SYMROOT" DSTROOT=/ install
