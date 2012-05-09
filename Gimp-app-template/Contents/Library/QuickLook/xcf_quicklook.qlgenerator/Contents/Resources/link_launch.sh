#!/bin/sh
#
# Author: Aaron Voisine <aaron@voisine.org>
# modified by: Christoph Schroeder <webmaster@wilber-loves-apple.org>
# modified by: Steven Borley <steven.borley@diode.demon.co.uk>
# addapted for quicklook plugin by: Pierre Andrews <mortimer.pa@free.fr>
# simplified by Simone Karin Lehmann, simone at lisanet dot de

#params: 
## $1 path to Gimp.app (not needed any longer)
## $2 file to resize
## $3 output file
## $4 max size

DIR=`dirname "$0"`
cd "$DIR/../../../../../.."
APPDIR=`pwd`
cd - > /dev/null
GIMP="$APPDIR/Contents/Resources/bin/gimp-2.6"

export GIMP2_DIRECTORY="Library/Application Support/Gimp"

LNDIR=/tmp/skl/Gimp.app
if [ ! -e "$LNDIR/Contents/Resources/Gimp.icns" ]; then
	rm -f "$LNDIR"
	mkdir -p /tmp/skl
	chmod a+w /tmp/skl
	ln -s "$APPDIR" "$LNDIR"
fi

if [ -e "$3" ]; then
	rm -f "$3"
fi

if [ -e /tmp/skl/dbus-address ]; then
  export DBUS_SESSION_BUS_ADDRESS=`cat /tmp/skl/dbus-address`
fi

"$GIMP" -i -d -f -b "(define (quicklook-xcf filename_in filename_out max_size)  (let* ((image (car (gimp-file-load RUN-NONINTERACTIVE filename_in filename_in))) (drawable (car (gimp-image-flatten image))) (original-width  (car (gimp-image-width  image))) (original-height (car (gimp-image-height image))) (t-height (* original-height (/ max_size original-width))) (t-width (* original-width (/ max_size original-height)))) (gimp-image-set-resolution image 72 72) (if (< original-width original-height) (gimp-image-scale-full image t-width max_size 2) (gimp-image-scale-full image max_size t-height 2)) (gimp-file-save RUN-NONINTERACTIVE image drawable filename_out filename_out)(gimp-image-delete image))) (quicklook-xcf \"$2\" \"$3\" $4)" -b '(gimp-quit 0)';
