#!/usr/bin/env perl -w
#
# cddb-format.pl
#
# Prints a text format CDDB file in HTML with links to cddb query for titles and names

#use lib "$ENV{HOME}/lib/perl5" ;

#use lib "/opt/local/lib/perl5/site_perl/5.16.3" ;

use strict ;
use utf8 ;
use URI::Encode ;
use MyUtil ;
use CddbMp3 ;

use vars qw($opt_h $opt_t $opt_a) ;
use Getopt::Std ;

use CGI '-utf8';

#Declarations
sub read_cddb_stdin ;
sub print_header ;
sub print_artist_and_title ;
sub print_tracks ;
sub print_debug_window ;
sub print_footer ;
sub print_cover_image ;
sub tokenize_anchors_title ;
#sub find_mp3 ;
sub printbr ;

#http://localhost/~paul/music/Bill_Evans/Yesterday_I_Heard_The_Rain/03%20-%20My_Romance.mp3

##DEFAULT GLOBALS
my $is_cgi = 0 ;
my $cddb_dir = '/home/r/riktov/.cddb/' ;
my $rcfilepath = '.cddbrc' ;

my $image_dir = "../cddb_images/" ;
my $album_covers_dir="../album_covers/" ;
#my @mp3_dirs = ('../ext_music/', '../music/') ;


#options
my $opt_html = 1 ;


################
## MAIN
#main starts here

if (open RCFILE, $rcfilepath) {
	my @rc = <RCFILE> ;
	
	foreach my $line (@rc) {
		if ($line =~ /cddb_dir=(.+)/) {
			$cddb_dir=$1 ;
		}
	}
	close RCFILE ;
}


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
my $infile = $cddb_dir . "/" .  $cgi->param('cddb') ;

#for command-line
if (!$infile) {
	#print "No CGI param provided\n" ;
	$infile = $ARGV[0] ;
}


#globals
my ($d_artist, $d_title, $num, $num_tracks) ;
my $is_compilation = 0 ;
my (@tr_title, @tr_artist, @tr_composer) ;

$infile or die "Can't get infile!\n" ;
#print "INFILE: $infile\n" ;
#die "Input file required\n" unless $infile ;

if (-l $infile) {
	$infile = readlink($infile) ;
	}

read_cddb($infile) ;


#output
if ($is_cgi) {
	print $cgi->header(
		-type    => 'text/html',
        -charset => 'utf-8');
}

my $cddb_id = $infile ;
$cddb_id =~ s|.+/|| ;


if($opt_html) {                   
	print $cgi->start_html(
	    -title=>"$d_title - $d_artist", 
	    -style=>'../css/cddb.css',
	    -head=> $cgi->Link({
			-href=>"../cddb_images/favicon/${cddb_id}_favicon.png",
			-type=>'image/png',
			-rel=>'icon',
			}),
		-script=>{
			-type=>'text/javascript',
			-src=>'../js/dragimage.js'
			}
		) ;
}
else {
	print "# $infile\n" ; 
}

print_artist_and_title();

CddbMp3::loadrc() ;

print_tracks();
print_cover_image() if $opt_html ;
print_debug_window() ;
print_footer();

#end of main()

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
    my ($d_artist_fmt, $d_title_fmt, $d_artist_link, $d_image_thumb) ;
    $d_artist_link = "" ;
    
    if ($opt_html) {
        if (!$is_compilation) {
            $d_artist_link = tokenize_anchors_artist($d_artist) ;
        }
        $d_artist_fmt = "<h2>$d_artist_link</h2>\n" ;
        
        $d_image_thumb = $image_dir . "thumbs/" . $cddb_id . "_th.png" ;
        
        $d_title_fmt  = "<h1>$d_title</h1>" ;
		}
    else {
        $d_artist_fmt = "#$d_artist - " ;
        $d_title_fmt  = $d_title ;
		}
		
    
    print '<div id="disc_title">' if $opt_html ;
    
    print "$d_artist_fmt" ;
    print "<div><img src=\"${d_image_thumb}\" />" if $opt_html;
    print "$d_title_fmt\n" ;
    
    print '</div></div>' if $opt_html ;
    
}


sub print_tracks()
{
    if($opt_html) {
        print '<div id="track_listing">' ;
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
            $title_html = '<b>' . MyUtil::tokenize_anchors_title($title) . '</b>' ;
            
            my $idx_1 = sprintf("%02d", $idx + 1) ;
            
            my $mp3_path = '' ;
            #$mp3_path = "$mp3_dir$d_artist/$d_title/$idx_1${title}.mp3" ;
            $mp3_path = CddbMp3::find_mp3_file($d_artist, $d_title, $idx_1, $title) ;
            
            #print "The mp3 path: $mp3_path" ;
            
            my $mp3_alink = '' ;
            
            if ($mp3_path ne '') { 
                $mp3_alink = '[<a href="' . $mp3_path . '">mp3</a>]' ;
            }
            
            print '<li>' ;
            print "$title_html$artist_html$composer_html ${mp3_alink}" ;
            print '</li>'  ;
        } else {
            print "$track_num $title$artist" ;
        }
        
        $track_num++ ;
    }
		
    if($opt_html) {
        print '</ol>' if $opt_html ;
        print '</div>' ;
    }
}

sub mp3_directory {
    my($artist, $album) = @_ ;

}

#return the path of the unprocessed album cover image, or '' if none
sub cover_source_image_path {
    my($artist, $album) = @_ ;

    my $path = "${artist}-${album}.jpg" ;
    $path =~ tr|[ '\&+;]|_| ;#replace illegal path characters

    #use utf8?
    #$path =~ tr/[ô]/[o]/ ;#replace extended characters, not working with multiple characters
    #$path =~ tr/[ãá]/[a]/ ;#replace extended characters
    $path = $album_covers_dir . $path ;
    return $path ;
}

sub print_cover_image() {
    my $imgfile = $infile ;
    $imgfile =~ s|.+/|$image_dir|;
    $imgfile = $imgfile . '.png' ;

    #print $imgfile . '</br>' ;
    
    print '<div id="album_cover">' ;
    
    if(-f $imgfile) {		
        print "<img src=\"$imgfile\">" ;
    } else {
        my $cover_source_image_path = cover_source_image_path($d_artist, $d_title) ;
        
        my $cover_convert_link = '' ;
	
        if(-f $cover_source_image_path) {
            #print $fixed_name ;
            $cover_convert_link = "<a href=cddb-convert-image.pl?source=${cover_source_image_path}&cddb=${infile}>Convert Cover Image</a>" ;
            print $cover_convert_link ;
        } else {
            print '<input type="file">Input File</input><br/>' ;
            print "Copy the image file to ${cover_source_image_path}" ;
        }
    }
    
    print '</div>' ;
    print '<br style="clear:both">' ;
}

sub printbr {
    my $line = shift ;
    print $line . '<br />' ;
}

sub print_debug_window {
    my $cover_path = cover_source_image_path($d_artist, $d_title) ;
    
    print '<div class="Debug"><code>' ;

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
	<li><a href="cddb-query.pl">Return to Query</a>
</ul>

</body>
</html>
EOF
    }
	else { print "\n" ; }
}
