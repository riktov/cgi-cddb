#!/bin/bash

#echo $1 
#exit 

FROM_ENCODING=`echo $QUERY_STRING | sed -e 's|from_encoding=\(.*\)&cddb_file.*|\1|'`
CDDB_FILE=`echo $QUERY_STRING | sed -e 's|.*cddb_file=\(.*\)|\1|'`
CDDB_FILE=`echo $CDDB_FILE | sed -e 's|\%2F|/|g'`



if [ "$QUERY_STRING" == "" ] ; then
    INFILE=$1
    OUTFILE="$INFILE.utf-8"
    FROM_ENCODING='whatever'
    echo "Console text mode"
    echo "#iconv -f $FROM_ENCODING -t utf-8 $INFILE > $OUTFILE ; mv $OUTFILE $INFILE "
else
    INFILE=$CDDB_FILE ;
    OUTFILE="$INFILE.utf-8"
    
    iconv -f $FROM_ENCODING -t utf-8 $INFILE > $OUTFILE ; mv $OUTFILE $INFILE
    chmod a+w $INFILE
    
    #TODO reload the page
    echo "Content-type: text/html"
    echo ""
    echo "<html><head></head><body>"
    #echo $QUERY_STRING
    echo "#iconv -f $FROM_ENCODING -t utf-8 $INFILE > $OUTFILE ; mv $OUTFILE $INFILE "
    echo ""
    echo "<a href=cddb-format.pl?cddb_path=$CDDB_FILE>Return</a>"
    echo "</body></html>"
fi


#iconv -f iso8859-1 -t utf-8 $INFILE > $OUTFILE ; mv $OUTFILE $INFILE 
#iconv -f eucjp -t utf-8 $INFILE > $OUTFILE && mv $OUTFILE $INFILE 

exit








INFILE_LN=`ls -la $INFILE | sed -e 's|^l.* -> \(.\+\)|\1|'`

echo $INFILE_LN 

OUTFILE=`echo $INFILE | sed -e 's|.*/\(.\+/.\+\)$|\1|'`

echo "in:$INFILE  out:$OUTIFLE"

exit

#echo $OUTFILE
iconv -f iso8859-1 -t utf8 $INFILE > "./$OUTFILE"