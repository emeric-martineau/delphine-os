#!/bin/bash

DOD=.  # Delphine OS Directory

parcours () {
    DIREU="`pwd`"
    case $ETAPE in
	search )  FUM="*.pp" ;;
    esac

    for i in $FUM; do     # Fichiers a traiter
	if [ -f $i ]; then
	    case $ETAPE in
		search ) 
			    TMP="`grep -n $STR $i`"
			    if [ "$TMP" != "" ]; then
			    	echo "|---------------------------------------- $i"
				echo "$TMP"
			    fi
				    
				    
			    ;;
	    esac
	fi
    done
    
    for i in ./*; do        # Sous repertoires a analyser
	if [ -d $i ] && [ ! $i = ".." ] && [ ! $i = "." ];  then
            cd $i
    	    parcours
	    cd ..
	fi
    done
}
	

if [ "$1" == "" ]; then
    echo " Donnez la chaine a chercher !!! : $1"
    exit
fi


# le rpertoire existe bien
if [ -d $DOD ]; then
    cd $DOD
    ETAPE=search
    STR="$1"
    parcours
else
    echo "le répertoire $DOD n'existe pas"
fi
