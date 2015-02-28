package Cddb ;

require Exporter ;
@ISA = qw(Exporter) ;

@EXPORT=qw(
	genre_and_id
) ;

sub genre_and_id {
	$fullpath = shift ;
	$fullpath =~ s|.*/(.+/.+)|$1| ;

	return $fullpath ;
}

#################################################
# Always put a return value in a module file
# http://dev.perl.org/perl6/rfc/269.html

1;

