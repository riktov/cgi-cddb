#!/usr/bin/perl -w
#
# cddb-format.pl
#
# Prints a text format CDDB file in HTML with links to cddb query for titles and names

#use lib "$ENV{HOME}/lib/perl5" ;

use strict ;
use utf8 ;
use URI::Encode ;
use MyUtil ;

use vars qw($opt_h $opt_t $opt_a) ;
use Getopt::Std ;

use CGI ;

#Declarations
sub read_cddb_stdin ;
sub print_header ;
sub print_artist_and_title ;
sub print_tracks ;
sub print_debug_window ;
sub print_footer ;
sub print_cover_image ;
sub tokenize_anchors_title ;
sub find_mp3 ;
sub printbr ;

#http://localhost/~paul/music/Bill_Evans/Yesterday_I_Heard_The_Rain/03%20-%20My_Romance.mp3

##GLOBALS
my $is_cgi = 0 ;
my $cddb_dir = '/home/r/riktov/.cddb/' ;
my $image_dir = "../cddb_images/" ;
my $album_covers_dir="/home/paul/Pictures/external/album_covers/" ;
my @mp3_dirs = ('../ext_music/', '../music/') ;

#options
my $opt_html = 1 ;


################
## MAIN
#main starts here


# command-line options
getopts('aht') ;
if ($opt_h)	{ $opt_html = 1 ; }	#HTML output
if ($opt_t)	{ $opt_html = 0 ; }	#text output


# start CGI
my $cgi = new CGI ;

$cgi->charset('utf-8');

my @names = $cgi->param ;
$is_cgi = 1 if @names ; 

#my $infile = $cgi->param('keywords') ;
my $infile = $cgi->param('cddb') ;

#for command-line
if (!$infile) {
	#print "No CGI param provided\n" ;
	$infile = $ARGV[0] ;
}

$infile or die "Can't get infile!\n" ;
#print "INFILE: $infile\n" ;

#globals
my ($d_artist, $d_title, $num, $num_tracks) ;
my $is_compilation = 0 ;
my (@tr_title, @tr_artist, @tr_composer) ;

die "Input file required\n" unless $infile ;
if (-l $infile) {
	$infile = readlink($infile) ;
	}

read_cddb($infile) ;


#output
if ($is_cgi) {
	print $cgi->header ;
}

my $cddb_id = $infile ;
$cddb_id =~ s|.+/|| ;


if($opt_html) {
	print $cgi->start_html(
	    -title=>"$d_title - $d_artist", 
	    -style=>'../css/cddb.css',
	    -head=> $cgi->Link({
		-href=>"../cddb_images/${cddb_id}_favicon.png",
		-type=>'image/png',
		-rel=>'icon'})) ;
}
else {
	print "# $infile\n" ; 
}

print_artist_and_title();
print_tracks();
print_cover_image() if $opt_html ;
print_debug_window() ;
print_footer();


sub read_cddb
	{
	my $filepath = shift ;
	open (INFILE, $filepath) or die "Can't open file $filepath\n";
	
	my ($track, $comment) ;

	my $line ;
	while ($line = <INFILE>) {
		if ($line =~ /DTITLE=(.+) \/ (.+)/) {
			$d_artist = $1 ;
			$d_title  = $2 ;
			if ($d_artist =~/^Various/i) {
				$is_compilation = 1 ;
				}
			}
	
		if ($line =~ /TTITLE(\d+)=(.+)/) {
			$num_tracks = $num = $1 ;
			$track = $2 ;
			
			$tr_title[$num] = $track ;
			$tr_artist[$num] = '' ;
			#print "$track\n" ;
			}
	
		if ($line =~ /TARTIST(\d+)=(.+)/) {
			$num = $1 ;
			$track = $2 ;
			
			$tr_artist[$num] = $track ;
			
			#print "$track\n" ;
			}
	
		if ($line =~ /EXTT(\d+)=(.*)/) {
			$num = $1 ;
			$comment = $2 ;
			
			$tr_composer[$num] = $comment ;
			#print "$num:$comment\n" ;
			}	
		}
	$d_artist or die "Couldn't parse disc artist in $infile\n" ;
	
	close INFILE ;
	}

sub print_artist_and_title()
{
	my ($d_artist_fmt, $d_title_fmt, $d_artist_link) ;
	if ($opt_html) {
		if (!$is_compilation) {
			$d_artist_link = tokenize_anchors_artist($d_artist) ;
		}
		$d_artist_fmt = "<h2>$d_artist_link</h2>\n" ;
		$d_title_fmt  = "<h1>$d_title</h1>" ;
		}
	else {
		$d_artist_fmt = "#$d_artist - " ;
		$d_title_fmt  = $d_title ;
		}
	print "$d_artist_fmt$d_title_fmt\n" ;
}


sub print_tracks()
{
    if($opt_html) {
	print '<div class="TrackListing">' ;
	print '<ol>'  ;
    }

	
	my $idx ;

	my ($track_fmt, $artist_html, $title_html, $mp3_html) ;

	my $track_num = 1 ;

	for($idx = 0 ; $idx <= $num_tracks ; $idx++) {
		$artist_html = '' ;
		my ($title, $artist, $composer) = ($tr_title[$idx], $tr_artist[$idx], $tr_composer[$idx]) ;

		$composer =~ tr/\(\)//d ;
		if ($artist ne '') {
			my $links = MyUtil::tokenize_anchors_artist($artist) ;
			$artist_html = " - $links" ;
			$artist = "\t$artist" ; 	#for console mode
		} 

		my $composer_html = MyUtil::tokenize_anchors_composer($composer) ;
		
		if ($composer_html ne '') {
			$composer_html = " <i><small>($composer_html)</small></i>" ;
		}

		if($opt_html) {
			my $links = MyUtil::tokenize_anchors_title($title) ;
			$title_html = "<b>$links</b>" ;

			my $idx_1 = sprintf("%02d", $idx + 1) ;

			
			my $mp3_path = '' ;
			#$mp3_path = "$mp3_dir$d_artist/$d_title/$idx_1${title}.mp3" ;
			$mp3_path = find_mp3($d_artist, $d_title, $idx_1, $title) ;

			#print $mp3_path ;

			my $mp3_alink = '' ;

			if ($mp3_path ne '') { 
			    $mp3_alink = '[<a href="' . $mp3_path . '">mp3</a>]' ;
			}

			$track_fmt = "<li>$title_html$artist_html$composer_html $mp3_alink"  ;
		} else {
			$track_fmt = "$track_num $title$artist" ;
		}
		print "$track_fmt" ;	
		
		$track_num++ ;
	}
		
    if($opt_html) {
	print '</ol>' if $opt_html ;
	print '</div>' ;
    }
}

sub find_mp3 {
    my($artist, $album, $tracknum, $title) = @_ ;

    #return 1 ;
    #mogrify the strings
#    my $tracknum_str = sprintf("%02d", $tracknum + 1) ;
    my $uri = URI::Encode->new( { encode_reserved => 0 } );

    $album =~ s/[ '\?\!]/_/g ;
    $artist =~ s/[ '\?\!]/_/g ;
    $title =~ s/[ '\?\!\/]/_/g ;

    foreach my $dir (@mp3_dirs) {
	my $mp3_path = "${dir}$artist/$album/$tracknum - $title" ; 
	$mp3_path = $mp3_path . '.mp3' ;

	#$mp3_path = $uri->encode($mp3_path) ;

#	print "<a href=\"$mp3_path\">" . $mp3_path. "</a>" ;

	if (-f $mp3_path) { 
#	    print '[' . $mp3_path. "]<br>" ;
	    return $mp3_path ;
	}
    }
    return '' ;
}

#return the path of the unprocessed album cover image
sub cover_source_image_path {
    my($artist, $album) = @_ ;

    my $path = "${artist}-${album}.jpg" ;
    $path =~ tr|[ '\&]|_| ;#replace illegal path characters

    #use utf8?
    $path =~ tr/[ô]/[o]/ ;#replace extended characters, not working with multiple characters
    $path =~ tr/[ãá]/[a]/ ;#replace extended characters
    $path = $album_covers_dir . $path ;
    return $path ;
}

sub print_cover_image() {
    my $imgfile = $infile ;
    $imgfile =~ s|.+/|$image_dir|;
    $imgfile = $imgfile . '.png' ;

    #print $imgfile . '</br>' ;

    if(-f $imgfile) {
	print '<img src="' . $imgfile . '">' ;
    } else {
	my $fixed_name = cover_source_image_path($d_artist, $d_title) ;

	my $cover_convert_link = '' ;

	if(-f $fixed_name) {
	    #print $fixed_name ;
	    $cover_convert_link = "<a href=cddb-convert-image.pl?source=$fixed_name&cddb=$infile>Convert Cover Image</a>" ;
	    print $cover_convert_link ;
	} 
    }
    print '<br style="clear:both">' ;
}

sub printbr {
    my $line = shift ;
    print $line . '<br />' ;
}

sub print_debug_window {
    my $cover_path = cover_source_image_path($d_artist, $d_title) ;
    
    print '<div class="Debug"><code>' ;

    printbr ($infile) ;
    printbr ("cddb-format.pl -t $infile") ;
    printbr ("kate $infile &") ;
    printbr ($cover_path) ;
    printbr ("$d_artist $d_title") ; 
    
    print '</code></div>' ;
    
}

sub print_footer()
{
    if($opt_html) {

	print<<EOF
<p>


<hr>
<form method="GET" action="iconv.cgi">
<p>
Convert to utf-8 from <select name=from_encoding>
	<option>iso8859-1
	<option>euc-jp
	</select>
	<input type=hidden name="cddb_file" value=$infile>
	<input type=submit value="Convert">
</form>

<ul>
	<li><a href="cddb-tartist.pl?cddb_path=$infile">Convert to TARTIST format</a>
	<li><a href="cddb-collection?$infile">Add to collection</a>
</ul>

</body>
</html>
EOF
    }
	else { print "\n" ; }
}
