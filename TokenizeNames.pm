package MyUtil ;

#Functions to split titles and names by punctuation and wrap each in anchors.
#Functions to "loosen" accented characters for matching with grep.

require Exporter ;
@ISA = qw(Exporter) ;

@EXPORT=qw(
	tokenize_anchors_artist
	tokenize_anchors_composer
	tokenize_anchors_title
	loosen_punctuation
	loosen_accent
) ;

#@EXPORT_OK=qw() ;

#sub tokenize_anchors_title ;
#sub tokenize_anchors_artist ;
#sub tokenize_anchors_composer ;
#sub html_query ;

#Since it is likely that a composer search will return many entries with the same composer team, instead of
#tokenizing the same anchors repeatedly, we memoize with a hash.
my %composer_anchor_of ;

my $cddb_query_script = 'cddb-query.pl' ; #may be changed

sub query_anchor
{
	my ($tag, $query) = @_ ;

	return ' ' if ($query eq '') ; 

	# ? must be escaped before going to CGI
	my $query_esc = $query ;
#	$query_esc =~s/&/%3F/g ;
	
	my $wikipedia_anchor = '' ;
	#$wikipedia_anchor = "<a href=\"http://en.wikipedia.org/wiki/$query\"><img src=\"../images/wp_icon.png\"></a>" ;
	
	return "<a href=\"${cddb_query_script}?$tag=$query\">$query</a>$wikipedia_anchor" ;
}

sub tokenize_anchors_title
{
	my $line = shift ;

	if (!$line) { return '' ; }
	
	#alternate title in parentheses
	if ($line =~ m|(.*)\((.+?)\)(.*)|) {
      my ($before, $title, $after) = ($1, $2, $3) ;
      
      return 
          tokenize_anchors_title($before) .
          '(' .
          tokenize_anchors_title($title) . 
          ')' . 
          tokenize_anchors_title($after) ;
	}
	
	#two tracks separated by slash or other single character surrounded by one or more spaces
	if ($line =~ m|(.+?)( +[/\-\&\~] +)(.*)|) {
      my ($before, $separator, $after) = ($1, $2, $3) ;
      
      return 
          tokenize_anchors_title($before) . 
          $separator . 
          tokenize_anchors_title($after) ;
	}
	
	#two tracks separated by colon without preceding space
	if ($line =~ m|(.+?)([:] )(.*)|) {
      my($before, $colon, $after) = ($1, $2, $3) ;
      
      return 
          tokenize_anchors_title($before) .
          $colon . 
          tokenize_anchors_title($after) ;
	}

	my $result = query_anchor('title', $line) ;
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
	
	my $result = query_anchor('artist', $line) ;
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
	} elsif ($line =~ m|(.+?)([,] )(.*)|) { #two names separated by comma, no space required before
		$result = tokenize_anchors_composer($1).$2.tokenize_anchors_composer($3) ;
	} else {
		$result = query_anchor('composer', $line) ;
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
  $string =~ s/í/\[ií\]/g ;
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

