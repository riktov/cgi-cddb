#!/usr/bin/perl -w
# cddb-query.pl
# CDDB search

use CGI ;
use strict ;
use English ; #for $PROGRAM_NAME
#use utf8 ;

use lib '/opt/local/lib/perl5/site_perl/5.16.3' ;
use Text::Unaccent::PurePerl ;
    
use MyUtil ;
use Cddb ;

#forward declarations
sub output_header_and_titles ;
sub output_list_args ;
sub output_footer;
sub output_results;
sub print_result_lines ;
sub print_result_albums ;
sub get_disc ;
sub get_track ;
sub pattern_accents ;
sub escape_chars ;
sub sort_i ;
sub lib_tokenize_anchors_artist ;
sub loosen_accent ;


#symbolic constants
my $re_dig = '[[:digit:]]' ;	#shorthand; man grep for details
#indexes of fields in the track info list structure
my $IDX_TITLE    = 0 ;
my $IDX_ARTIST   = 1 ;
my $IDX_COMPOSER = 2 ;

#globals
my $cddb_dir = '/home/r/riktov/.cddb/' ;
my $cddb_image_dir = "../cddb_images/" ;
my $cddb_image_thumbs_dir = "../cddb_images/thumbs/" ;
my $cddb_image_favicon_dir = "../cddb_images/favicon/" ;
my $rcfilepath = '.cddbrc' ;

my %composer_of ;

#options
my $g_debug = 1 ;
my $g_is_admin = 0 ;


##############################################################
# main

if (open RCFILE, $rcfilepath) {
	my @rc = <RCFILE> ;
	
	foreach my $line (@rc) {
		if ($line =~ /cddb_dir=(.+)/) {
			$cddb_dir=$1 ;
		}
	}
	close RCFILE ;
}


#who am I?
my $cgi_url = $PROGRAM_NAME ;
$cgi_url =~ s|(.*/)|| ;


###############################
# Get the CGI variables
my $query = CGI->new() ;
my @names = $query->param ;

my $server_name = $query->server_name() ;
my $remote_addr = $query->remote_addr() ;
my $remote_host = $query->remote_host() ;

$g_is_admin = 1 if $remote_addr eq 'localhost' ;

my $artist   = $query->param('artist') ;
my $title    = $query->param('title') ;
my $composer = $query->param('composer') ;
my $sortby   = $query->param('sortby') ;

$query->charset('utf-8');


my $doc_title = "CDDB Query" ;

###############################
# start output here
print $query->header ;
print $query->start_html(-title=>$doc_title,
			 -style=>'../css/cddb.css',
			 -script=>[
					{ -type => 'text/javascript',
					  -src => '../js/sorttable.js'
					}
				]
			) ;

print '<div id="program_description">' ;
print "<h1>$doc_title</h1>\n" ;	

print "<h2>\$remote_addr:$remote_addr</h2>\n" if $g_debug ;
print "<h2>\$remote_host:$remote_host</h2>\n" if $g_debug ;

print '</div>' ;

#run in different modes
if (! -d $cddb_dir) {	#error
	print "<p>Invalid \$cddb_dir: $cddb_dir\n" ;
} elsif (!@names) {	#no query, just input form
	print_query_form() ;
}
else {			#process query
	print_query_form() ;
	
	my ($tag, $querystring, $query_albums) ;

	my @queries = create_queries() ;
	my $grep_cmd_query = pop @queries ;
	
	($tag, $querystring) = split "\t", $grep_cmd_query ;
	
	my $grep_cmd_tracks = grep_command_line($tag, $querystring, 0) ;
	my $grep_cmd_albums = grep_command_line($tag, $querystring, 1) ;
	
	print '<div id="found_tracks">' ;
	print "<h2>Tracks</h2>" ;
	print "<p><code>$grep_cmd_tracks</code><p>" if $g_debug ;

	my @found_grep = grep_results($grep_cmd_tracks) ;
		
	push @found_grep, $tag ;
	my @found_tracks = grep_output_to_trackinfo(@found_grep) ;
	
	foreach my $query (@queries) {
		@found_tracks = apply_query(\@found_tracks, $query) ;
	}

	my @sorted_tracks ;
	my $sortref = sort_func($tag) ;
	@sorted_tracks = sort $sortref @found_tracks ;
	
	print_result_tracks(@sorted_tracks) ;
	print '</div>' ;
	
	print '<div id="found_albums">' ;	
	print "<h2>Albums</h2>" ;
	print "<code>$grep_cmd_albums</code>" if $g_debug ;

	my @found_albums ;
	@found_albums = grep_results($grep_cmd_albums) ;
	
	print_result_albums(@found_albums) ;
	print '</div>' ;
}

print $query->end_html ;

##### end of main
##############################################################



sub print_query_form {
	$title     = '' if !$title ;
	$composer  = '' if !$composer ;
	$artist    = '' if !$artist ;
	
	print<<END_HERE
<div id="query_form">
<form method=GET class="CDDBQuery">
	<div>
		Title: <input name='title' value="$title">
	</div>
	<div>
		Artist: <input name='artist' value="$artist">
	</div>
	<div>
		Composer: <input name='composer' value="$composer">
	</div>
	<input type=submit value='Search'>
</form>
</div>
END_HERE
}


sub create_queries {
	#return a list of references to query structures, which are tag-querystring pairs.
	my ($tag, $querystring) ;

	my @queries = () ;

	# Order is important here. Since an artist query may return albums but no tracks, further queries on composer or title will not work,
	# even though we want to query on composer/title for all the tracks in that album.
	# So we always place artist at the bottom of the stack.
	# Title will probably return fewer hits than composer, so we place that at the top. 
	push @queries, "TARTIST\t$artist" if ($artist) ;
	push @queries, "EXTT\t$composer"  if ($composer) ;
	push @queries, "TTITLE\t$title"   if ($title) ;

	return @queries ;	
}

sub apply_query {
	my ($tracksref, $query) = @_ ;
	
	my @trackinfo_refs = @{$tracksref} ;
	
	my($tag, $querystring) = split "\t", $query ;
	
	my $idx ;
	
	$idx = $IDX_TITLE    if ($tag eq 'TTITLE') ;
	$idx = $IDX_ARTIST   if ($tag eq 'TARTIST') ;
	$idx = $IDX_COMPOSER if ($tag eq 'EXTT') ;
	
#	foreach my $ref (@trackinfo_refs) {
#		my @track = @{$ref} ;
#		print join ':', @track ;
#		print '<br>' ;
#	}
	
	return grep {
		my @track = @{$_} ;
		$track[$idx] =~ /$querystring/i ;
	} @trackinfo_refs ;
}

sub query_pred_artist {
	
}

sub loosen_accent {
    my $string = shift ;

    my $unaccented = unac_string($string) ;
    return $unaccented ;
}

sub grep_command_line {
    #tags	
    my($tag, $querystring, $is_album_query) = @_ ;
    
    $querystring = escape_chars(loosen_accent(loosen_punctuation($querystring))) ;
    #also escape parentheses
    
    my $query_pattern ;
    
    if ($is_album_query) {
        if ($tag eq 'TTITLE' or $tag eq 'EXTT') {	# Look for composer in disc title, e.g., "Eliane Elias / Plays the Songs of Jobim"
            $query_pattern = "\"DTITLE=.* / .*$querystring\"" ;				
        } elsif ($tag eq 'TARTIST') {
            $query_pattern = "\"DTITLE=.*$querystring.* / \"" ;		
        }
    } else {
        if ($querystring =~ /\^(.+)/) {
            $query_pattern = "\"$tag$re_dig$re_dig?=\\(?$1\"" ;		#optional parentheses wrapping composer		
        } else {
            $query_pattern = "\"$tag$re_dig$re_dig?=.*$querystring\"" ;			
        }
    }
    
    my $cddb_spec = '*' ;	#genre subdirectories
    #	my $locale_spec = qq(LANG="ja_JP.UTF-8") ;
    #TODO: maybe use Perl locale module?
    #	my $locale_spec = qq(LANG="en_US.UTF-8") ;
    my $locale_spec = qq(LANG="pt_BR.UTF-8") ;
    
    return qq(export $locale_spec ; egrep -i -d recurse -e $query_pattern $cddb_dir$cddb_spec) ;
}



sub grep_results {
	my $egrep_cmd = shift ;
	
	#filter out backup files. Or make grep recurse with a filter on filenames
	my @found_grep = grep m|/[0-9a-z]{8}:|, `$egrep_cmd` ;
	
	return @found_grep ;
}


sub output_list_args {
	
	print "<ol>\n" ;
	
	foreach my $name (@names) {
		my $val = $query->param($name) ;
		print "<li>$name : $val\n" ;
	}
	print "</ol>\n" ;
}

sub get_track_info {
	# Given a line of output from a grep search of CDDB files, return a list of all CDDB info for that track:
	# cddb_path, title, artist, composer, album, track_number

	my ($tag, $grepline) = @_ ;

	#parse a line of grep output with found TTITLE/TARTIST/EXTT
	my($cddb_path, $track_num, $query_match) = split /:$tag|=/, $grepline ;

	my $album = get_disc('DTITLE', $cddb_path) ;
	my ($album_artist, $album_title) = split ' / ', $album ;
		
	my($title, $artist, $composer) ;
	
	if ($tag eq 'EXTT') {
		$composer =  $query_match ; 
	} else {
		$composer  = get_track_line_value('EXTT', $cddb_path, $track_num) ;
	}

	if ($tag eq 'TTITLE') {
		$title =  $query_match ;
	} else {
		$title = get_track_line_value('TTITLE',  $cddb_path, $track_num) ;
	}
	
	if ($tag eq 'TARTIST') {
		$artist =  $query_match ; 
	} else {
		$artist = get_track_line_value('TARTIST', $cddb_path, $track_num) ;
	}

	$composer  =~ tr/\(\)//d ;	#composers in EXTT are enclosed in parentheses
	if (!$artist) { $artist = $album_artist ; }

	my $uniq = 0 ;	#Hack
	if($uniq) {
		$title =~ s/( \(.*\))// ;	# strip out alternate titles
		$title =~ s/( \[.*\])// ;	# strip out track info
		
		if ($composer_of{uc $title}) {
			next ;
		} else {
			$composer_of{uc $title} = $composer ;
		}
	}
		
	$track_num++ ; #done with indexing, so now normalize to 1-based for printing
	
	return($title, $artist, $composer, $album, $track_num, $cddb_path) ;
}

sub sort_by_title    { @{$a}[$IDX_TITLE]    cmp @{$b}[$IDX_TITLE]; }
sub sort_by_artist   { @{$a}[$IDX_ARTIST]   cmp @{$b}[$IDX_ARTIST]; }
sub sort_by_composer { @{$a}[$IDX_COMPOSER] cmp @{$b}[$IDX_COMPOSER]; }

sub grep_output_to_trackinfo
#convert array of string output from grep to a list of track info records 
{
	my $tag = pop @_ ;
	my @foundgrep = @_ ;

	@foundgrep or return ;

	my @tracks = () ;
	
	foreach my $grepline (@foundgrep) {
		chomp $grepline ;
#		$grepline =~ s/^$cddb_dir// ;

		#parse the grep output
		#$cddb_path, $title, $artist, $composer, $album, $track_num
		my @info = get_track_info($tag, $grepline) ;
		
		push @tracks, \@info ;
	}

	return @tracks ;
}

sub sort_func
{
	my $sortref ;
	my $tag = shift ;
	
	#first let the tag determine the sort
	$sortref = \&sort_by_title    if ($tag eq 'TTITLE') ;
	$sortref = \&sort_by_artist   if ($tag eq 'TARTIST') ;
	$sortref = \&sort_by_composer if ($tag eq 'EXTT') ;

	$sortby = 'title' unless $sortby ;
	
	#but let it be overridden with the 'sortby' param
	if ($sortby eq 'title') {
		$sortref = \&sort_by_title ;
	}
	if ($sortby eq 'artist') {
		$sortref = \&sort_by_artist ;
	}
	if ($sortby eq 'composer') {
		$sortref = \&sort_by_composer ;
	}
	
	return $sortref ;
}

sub print_result_tracks
{
    # print results in trackinfo list format as an HTML table
    #
    
    my @tracks = @_ ;
    my @output_lines ;
    
    ##########
    ##########
    
    foreach my $inforef (@tracks) {
        my ($title, $artist, $composer, $album, $track_num, $cddb_path) = @{$inforef} ;
        
        my $cddb = $cddb_path ;
        $cddb =~ s|.+/|| ;
        
        my $thumbnail_path = $cddb_image_thumbs_dir . $cddb . '_th.png';
        
        #print $thumbnail_path ;
        my $thumbnail_link = '' ;
        
        if(-f $thumbnail_path) {
            $thumbnail_link = "<img src=\"$thumbnail_path\">" ;
        }
        
        my $cddb_genre_and_id = Cddb::genre_and_id($cddb_path) ;
        
        my $album_view_anchor = $thumbnail_link . "<div><a href=cddb-format.pl?cddb=$cddb_genre_and_id>$album</a></div>" ;
        
        my $title_html    = '<b>'.tokenize_anchors_title($title).'</b>' ;
        my $composer_html = '<i>'.tokenize_anchors_composer($composer).'</i>' ;
        my $artist_html   = tokenize_anchors_artist($artist) ;
        
        my $li_html ;
        
        my $checkbox = '';
        $checkbox = "<input type='checkbox' name=\"$cddb\">" if $g_is_admin ;
        
        # $li_html = "<li>$title_html : $composer_html : $artist_html -- $disc_html [$track_num] : \n" ;		
        $li_html = "<tr>" .
            "<td>$title_html</td>" .
            "<td>$composer_html</td>" .
            "<td>$artist_html</td>" .
            "<td>$checkbox$album_view_anchor</td>" .
            "<td>$track_num</td></tr>" ;
        
        
        my $uniq = 0 ;	#Hack
        #		if (!$uniq) { $li_html .= " : <a href=\"cddb-query.pl?artist=$artist\">$artist</a>" }
        
        push @output_lines, "$li_html" ;
    }
    
    #
    print "<form method=GET action=\"cddb-collect.cgi\">\n" ;
    
    my ($header_anchor_title, $header_anchor_composer, $header_anchor_artist) ;
    
    #$header_anchor_title    = "<a href=\"cddb-query.pl?title=$title&artist=$artist&composer=$composer&sortby=title\">" ;
    #$header_anchor_composer = "<a href=\"cddb-query.pl?title=$title&artist=$artist&composer=$composer&sortby=composer\">" ;
    #$header_anchor_artist   = "<a href=\"cddb-query.pl?title=$title&artist=$artist&composer=$composer&sortby=artist\">" ;
		
    my ($classtag_title, $classtag_composer, $classtag_artist) = ('', '', '');
    
    #$classtag_artist   =' class="SortKey"' if($sortby eq 'artist') ;
    #$classtag_composer =' class="SortKey"' if($sortby eq 'composer') ;
    #$classtag_title    =' class="SortKey"' if($sortby eq 'title') ;
    
    print '<table class="sortable" id="found_tracks">' ;
    
    #table header	
    print "\t<tr>" ;
    print "<th>Title</th>" ;
    print "<th>Composer</th>" ;
    print "<th>Artist</th>" ;
    print "<th>Album</th><th>Track No.</th></tr>\n" ;
    
    print join '', @output_lines ;
    
    print "</table>\n" ;
    
    print "<input type=submit value='Add to collection'>\n" ; 
    
    print "</form>\n" ;
    
}


sub print_result_albums()
{
	my $sep = '{' ;	#something that will never appear in an artist or album name	
	my @albums = @_ ;
	my @sorted = sort sort_i map { local $_ = $_ ; s|(.+):DTITLE=(.+) / (.+)|$2$sep$3$sep$1| ; $_ } @albums ;    

	print "<ul>";
	foreach my $line (@sorted) {
		$line =~ m|(.+)$sep(.+)$sep(.+)| ;
		my ($artist, $album, $cddb_path) = ($1, $2, $3) ;
		print '<li>';

		my $cddb = $cddb_path ;
		$cddb =~ s/.*\/// ;
		
		my $thumbnail_path = $cddb_image_thumbs_dir . $cddb . '_th.png';

		#print $thumbnail_path . "<br/>" ;
		my $thumbnail_link = '' ;

		if(-f $thumbnail_path) {
		    $thumbnail_link = "<img src=\"$thumbnail_path\">" ;
		    print $thumbnail_link ;
		}
		
		my $cddb_genre_and_id = Cddb::genre_and_id($cddb_path) ;
    print '<div>' ;
		print MyUtil::tokenize_anchors_artist($artist)." : <a href=\"cddb-format.pl?cddb=${cddb_genre_and_id}\">".$album ;
    print '</div>' ;
		print '</a>' ;
	}
	print "</ul>"; 
}

sub get_track_line_value()
	{
	my ($tag, $cddb_path, $track_num) = @_ ;

	my $pat = "$tag$track_num=" ;

	# some EXTTs are multi-line
	my $title = join('', `grep $pat "$cddb_path"`) ;
	
#	print $title ;	
	chomp $title ;
	$title =~ s/\n//g ;
	$title =~ s/\\n/\n/g ;
	$title =~ s/$pat//g ;
	
	return $title ;
	}

sub get_disc()
	{
	my ($tag, $cddb_path) = @_ ;
	
	my $disc = `grep $tag "$cddb_path"` ;
	
	chomp $disc ;
	$disc =~ s/$tag=// ;
	
	return $disc ;
	}

sub escape_chars() {
	my $string = shift ;

	$string =~ s/\(/\\(/g ;
	$string =~ s/\)/\\)/g ;

	return $string ;
}

sub sort_i { lc($a) cmp lc($b);
}
