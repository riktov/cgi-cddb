package MyUtil ;

require Exporter ;
@ISA = qw(Exporter) ;

@EXPORT=qw(
	tokenize_anchors_artist
	tokenize_anchors_composer
	tokenize_anchors_title
	loosen_punctuation
) ;

#	loosen_accent


#@EXPORT_OK=qw() ;

#sub tokenize_anchors_title ;
#sub tokenize_anchors_artist ;
#sub tokenize_anchors_composer ;
#sub html_query ;

#Since it is likely that a composer search will return many entries with the same composer team, instead of
#tokenizing the same anchors repeatedly, we memoize with a hash.
my %composer_anchor_of ;

sub html_query
{
	my ($tag, $query) = @_ ;

	return ' ' if ($query eq '') ; 

	# ? must be escaped before going to CGI
	my $query_esc = $query ;
#	$query_esc =~s/&/%3F/g ;
	
	my $wikipedia_anchor = '' ;
	#$wikipedia_anchor = "<a href=\"http://en.wikipedia.org/wiki/$query\"><img src=\"../images/wp_icon.png\"></a>" ;
	
	return "<a href=\"cddb-query.pl?$tag=$query\">$query</a>$wikipedia_anchor" ;
}

sub tokenize_anchors_title
{
	my $line = shift ;

	if (!$line) { return '' ; }
	
	#alternate title in parentheses
	if ($line =~ m|(.*)(\()(.+?)(\))(.*)|) {
		return tokenize_anchors_title($1).$2.tokenize_anchors_title($3).$4.tokenize_anchors_title($5) ;
	}
	
	#two tracks separated by slash or other single character
	if ($line =~ m|(.+?)( +[/\-\&\~] +)(.*)|) {
		return tokenize_anchors_title($1).$2.tokenize_anchors_title($3) ;
	}
	
	#two tracks separated by colon without preceding space
	if ($line =~ m|(.+?)([:] )(.*)|) {
		return tokenize_anchors_title($1).$2.tokenize_anchors_title($3) ;
	}

	my $result = html_query('title', $line) ;
	return $result ;
}

sub tokenize_anchors_artist
{
	my $line = shift ;

	if ($line eq '') { return '' ; }
	
	#alternate title in parentheses
#	if ($line =~ m|(.*)(\()(.+?)(\))(.*)|) {
#		return tokenize_anchors_title($1).$2.tokenize_anchors_title($3).$4.tokenize_anchors_title($5) ;
#	}
	
	if (
	    ($line =~ m|(.+?)( +[/\-\&\+] +)(.*)|) or	#space-delimited punctuation
	    ($line =~ m|(.+?)([,:] )(.*)|) 	#comma or colon has no preceding space
	   ) {
		return tokenize_anchors_artist($1).$2.tokenize_anchors_artist($3) ;
	}

	if ($line =~ m/(.*?)( *)\b(e|featuring|with|and)( +)(.*)/i) {
		return tokenize_anchors_artist($1).$2.$3.$4.tokenize_anchors_artist($5) ;
		#words
	}
	
	my $result = html_query('artist', $line) ;
	return $result ;

}



sub tokenize_anchors_composer
{
	my $line = shift ;

	if ($line eq '') { return '' ; }

	if ($composer_anchor_of{$line}) {
		#print STDERR "Found anchor hash: $line => $composer_anchor_of{$line}\n" ;
		return $composer_anchor_of{$line} ;
	}

	if ($line =~ m|(.+?)( +[/\-\&] +)(.*)|) { #two names separated by slash or other characters bordered by spaces
		$result = tokenize_anchors_composer($1).$2.tokenize_anchors_composer($3) ;
	} elsif ($line =~ m|(.+?)([,] )(.*)|) { #two tracks separated by comma
		$result = tokenize_anchors_composer($1).$2.tokenize_anchors_composer($3) ;
	} else {
		$result = html_query('composer', $line) ;
	}

	$composer_anchor_of{$line} = $result ;

	return $result ;
}

sub loosen_accent
{
#converts accented characters in a string to a set of unaccented and accented variants of that character
	my $string = shift ;

	$string =~ s/ã/\[aã\]/g ;
	$string =~ s/á/\[aá\]/g ;
	$string =~ s/é/\[eé\]/g ;
	$string =~ s/ê/\[eê\]/g ;
	$string =~ s/ó/\[oó\]/g ;
	$string =~ s/ô/\[oô\]/g ;
	$string =~ s/ú/\[uú\]/g ;

	$string =~ s/Á/\[AÁ\]/g ;
	$string =~ s/É/\[EÉ\]/g ;

	$string =~ s/ç/\[cç\]/g ;

	return $string ;	
}

sub loosen_punctuation {
	# fuzzy punctuation
	my $string = shift ;

	$string =~ s/([,'!\?])/$1?/g ;
#	$string =~ s/\./\\.?/g ;	

	return $string ;	
}

sub load_collection_db
{
	
}


#################################################
# Always put a return value in a module file
# http://dev.perl.org/perl6/rfc/269.html

1;

