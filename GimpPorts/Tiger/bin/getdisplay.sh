#!/bin/sh
#
# Author: Aaron Voisine <aaron@voisine.org>
# $Id: getdisplay.sh 13 2007-12-15 19:27:35Z sjborley $

if [ "$DISPLAY"x == "x" ]; then
    echo :0 > /tmp/$UID/TemporaryItems/display
else
    echo $DISPLAY > /tmp/$UID/TemporaryItems/display
fi
