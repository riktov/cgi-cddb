package Cddb ;

require Exporter ;
@ISA = qw(Exporter) ;

@EXPORT=qw(
genre_and_id
artist_and_title
) ;

sub genre_and_id {
	$fullpath = shift ;
	$fullpath =~ s|.*/(.+/.+)|$1| ;

	return $fullpath ;
}

sub artist_and_title {
    my $fullpath = shift ;
    
    open (INFILE, $fullpath) or die "Can't open file $fullpath\n";

    while ($line = <INFILE>) {
        if ($line =~ /DTITLE=(.+) \/ (.+)/) {
            $artist = $1 ;
            $title  = $2 ;      
            return ($artist, $title) ;
        }
    }
    return ("UNKNOWN", "UNKNOWN") ;
}

#################################################
# Always put a return value in a module file
# http://dev.perl.org/perl6/rfc/269.html

1;

