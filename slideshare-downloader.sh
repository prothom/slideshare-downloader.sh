#!/bin/bash
# Author: Andrea Lazzarotto
# http://andrealazzarotto.com
# andrea.lazzarotto@gmail.com

# Slideshare Downloader
# This script takes a slideshare presentation URL as an argument and
# carves all the slides in flash format, then they are converted to
# and finally merged as a PDF

# License:
# Copyright 2010-2011 Andrea Lazzarotto
# This script is licensed under the Gnu General Public License v3.0.
# You can obtain a copy of this license here: http://www.gnu.org/licenses/gpl.html

# Usage:
# slideshare-downloader.sh URL [SIZE]

#-----------------------------------------------
# Modify 7/08/2011 by giudinvx
# Email  giudinvx[at]gmail[dot]com 
#-----------------------------------------------
# Modify 20/Jul/2014 by schkateboarder
# Email schkateboarder@gmail.com
#-----------------------------------------------

validate_input() {
	# Performs a very basic check to see if the url is in the correct form
	URL=`echo "$1" | cut -d "#" -f 1 | cut -d "/" -f 1-5`
	DOMAIN=`echo "$URL" | cut -d "/" -f 3`
	DOMAIN=${DOMAIN#*.}
	CORRECT='slideshare.net'
	if [[ "$DOMAIN" != "$CORRECT" ]];
		then
			echo "Provided URL is not valid."
			exit 1
	fi
	
	if echo -n "$2" | grep "^[0-9]*$">/dev/null
		then SIZE=$2
		else
			SIZE=2000
			echo "Size not defined or invalid... defaulting to 2000."
	fi
}

check_dependencies() {
	# Verifies if all binaries are present
	DEP="wget sed seq convert"
	ERROR="0"
	for i in $DEP; do
		WHICH="`which $i`"
		if [[ "x$WHICH" == "x" ]];
			then
				echo "Error: $i not found."
				ERROR="1"
		fi
	done
	if [ "$(which swfdec-thumbnailer)" != "" ]; then
	    THUMB="swfdec-thumnailer"
	elif [ "$(which gnash-thumbnailer)" != "" ]; then
	    THUMB="gnash-thumnailer"
	else
	    echo "Error: gnash-thumbnailer and swfdec-thumbnailer not found. This script needs one of them to convert."
	    exit 1
	fi

	if [ "$ERROR" -eq "1" ];
		then
			echo "You need to install some packages."
			echo "Remember: this script requires Imagemagick and Swfdec."
			exit 1
	fi
}

build_params() {
	# Gathers required information
	DOCSHORT=`echo "$1" | cut -d "/" -f 5`
	echo "Download of $DOCSHORT started."
	echo "Fetching information..."
	INFOPAGE=`wget -q -O - "$1"`

	DOCID=`echo "$INFOPAGE" | grep -o -E 'doc=[a-zA-Z0-9-]*' | head -1`
	DOCID=${DOCID:4}
		echo $DOCID

	SLIDES=`echo "$INFOPAGE" | grep "totalSlides" | head -n 1 | sed -s "s/.*totalSlides//g" | cut -d ":" -f 2 | cut -d "," -f 1`
	echo "Slides: $SLIDES"
	echo "Size: $SIZE"
}

create_env() {
	# Finds a suitable name for the destination directory and creates it
	DIR=$DOCSHORT
	if [ -e "$DIR" ];
		then
			I="-1"
			OLD=$DIR
			while [ -e "$DIR" ]
			do
				I=$(( $I + 1 ))
				DIR="$OLD.$I"
			done
	fi
	mkdir "$DIR"
}

fetch_slides() {
	for i in $( seq 1 $SLIDES ); do
		echo "Downloading slide $i"
		wget "http://s3.amazonaws.com/slideshare/`echo $DOCID`-slide-`echo $i`.swf" -q -O "$DIR/slide-`echo $i`.swf"
	done
	echo "All slides downloaded."
}

convert_slides() {        
	for i in $( seq 1 $SLIDES ); do
		echo "Converting slide $i"
		if [ "$(which swfdec-thumbnailer)" != "" ]; then
		    THUMB="swfdec-thumbnailer"
		    $THUMB -s $SIZE $DIR/slide-$i.swf $DIR/slide-$i.png 2>/dev/null
		elif [ "$(which gnash-thumbnailer)" != "" ]; then
		    THUMB="gnash-thumbnailer"
		    $THUMB $DIR/slide-$i.swf $DIR/slide-$i.png $SIZE 2>/dev/null
		fi
		    
	done
	echo "All slides converted."
}

build_pdf() {
	IMAGES=`ls slide-*.png | sort -V`
	echo "Generating PDF..."
       
	for i in $IMAGES; do
	    convert $i $i.pdf
	done
	PDFS=`ls slide-*.pdf | sort -t"-" -k 2 -h`
	gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sOutputFile="$DOCSHORT".pdf $PDFS

	echo "The PDF has been generated."
	echo "Find your presentation in: \"`pwd`/$DIR/$DOCSHORT.pdf\""
}

clean() {
	rm -rf $DIR/slide-*.swf
	rm -rf $DIR/slide-*.png
	for i in $PDFS; do
	    rm -f $DIR/$i
	done
}

validate_input $1 $2
check_dependencies
build_params $URL
create_env
fetch_slides
convert_slides
pushd "$DIR"
build_pdf
popd
clean
