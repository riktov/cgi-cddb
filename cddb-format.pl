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
use TokenizeNames ;
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
my $cddb_dir = "/Users/paul/.cddbslave" ;
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
my $genre_and_cddb = $cgi->param('cddb') ;
my $cddb_id = $genre_and_cddb ;
$cddb_id =~ s|.+/|| ;
my $infile = $cddb_dir . "/" .  $genre_and_cddb ;

#for command-line
if (!$infile) {
	#print "No CGI param provided\n" ;
	$infile = $ARGV[0] ;
}

#globals
#my ($num) ;
#my $is_compilation = 0 ;
#my (@tr_title, @tr_artist, @tr_composer) ;

$infile or die "Can't get infile!\n" ;
#print "INFILE: $infile\n" ;
#die "Input file required\n" unless $infile ;

if (-l $infile) {
    #print STDERR "The file $infile is a link\n" ;
    my $link_dest = readlink($infile) ;
    if ($link_dest =~ m|^/|) {
        $infile = $link_dest ;
    } else {
        $infile =~ s|(.+/).+|$1| ;#trim file from last directory
        $infile = $infile . $link_dest ;
    }
    #print STDERR "The linked file is $infile\n" ;
	}


#read cddb here 
my %cddb_info = read_cddb($infile) ;

#output
if ($is_cgi) {
    print $cgi->header(
        -type    => 'text/html',
        -charset => 'utf-8');
}

if($opt_html) {              
    my $artist = $cddb_info{artist} ;
    my $title = $cddb_info{title} ;
    
    print $cgi->start_html(
        -title=>"$title - $artist", 
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

CddbMp3::loadrc() ;

print_artist_and_title(\%cddb_info);
print_tracks(\%cddb_info);
print_cover_image(\%cddb_info) if $opt_html ;
print_debug_window(\%cddb_info) ;
print_footer();

##############################################################################
#end of main()

sub read_cddb
	{
	my $filepath = shift ;
	open (INFILE, $filepath) or die "Can't open file $filepath\n";
	
	my ($artist, $title, $num_tracks, $num, $track, $is_compilation) ;
  
  my %cddb_disc ;
  my (@track_titles, @track_artists, @track_extras) ;
	my $line ;
	while ($line = <INFILE>) {
		if ($line =~ /DTITLE=(.+) \/ (.+)/) {
			$artist = $1 ;
			$title  = $2 ;      
			if ($artist =~/^Various/i) {
				$is_compilation = 1 ;
				}
			}
	
		if ($line =~ /TTITLE(\d+)=(.+)/) {
        ($num, $track) = ($1, $2) ;
        $track_titles[$num] = $track ;
        $track_artists[$num] = '' ;
        $num_tracks = $num ; 			
    }
    
		if ($line =~ /TARTIST(\d+)=(.*)/) {
        $num = $1 ;
        $track = $2 ;
        $track_artists[$num] = $track ;
    }
    
		if ($line =~ /EXTT(\d+)=(.*)/) {
        $num = $1 ;
        $track = $2 ;
        $track_extras[$num] = $track ;
    }	
  }
	$artist or die "Couldn't parse disc artist in $infile\n" ;
	
	close INFILE ;

  $cddb_disc{artist} = $artist ;
  $cddb_disc{title} = $title ;
  $cddb_disc{num_tracks} = $num_tracks ;
  $cddb_disc{is_compilation} = $is_compilation ;
  $cddb_disc{track_titles} = \@track_titles ;
  $cddb_disc{track_artists} = \@track_artists ;
  $cddb_disc{track_extras} = \@track_extras ;
  
  return %cddb_disc ;
	}

sub print_artist_and_title()
{
    my $cddb_ref = shift ;
    my %cddb = %$cddb_ref ;
    
    my $artist = $cddb{artist} ;
    my $title  = $cddb{title} ;
    
    my ($d_artist_fmt, $d_title_fmt, $d_artist_link, $d_image_thumb) ;
    $d_artist_link = "" ;

    if ($opt_html) {
        $d_artist_link = tokenize_anchors_artist($artist) ;
        $d_artist_fmt = "<h2>$d_artist_link</h2>\n" ;
        
        $d_image_thumb = $image_dir . "thumbs/" . $cddb_id . "_th.png" ;
        
        $d_title_fmt  = "<h1>$title</h1>" ;
        
        print '<div id="disc_title">';
        print "$d_artist_fmt" ;
        print "<div><img src=\"${d_image_thumb}\" />" ;		
        print "$d_title_fmt\n" ;
        print '</div></div>' ;
    } else {
        $d_artist_fmt = "#${artist} - " ;
        $d_title_fmt  = $title ;
        print "$d_artist_fmt" ;
        print "$d_title_fmt\n" ;		
    }
}


sub print_tracks()
{
    my $cddb_ref = shift ;
    my %cddb = %$cddb_ref ;
    
    my $track_titles_ref  = $cddb{track_titles} ;
    my @track_titles = @$track_titles_ref ;
    my $track_artists_ref = $cddb{track_artists} ;
    my @track_artists = @$track_artists_ref ;
    my $track_extras_ref  = $cddb{track_extras} ;
    my @track_extras = @$track_extras_ref ;

    if($opt_html) {
        print '<div id="track_listing">' ;
        print '<ol>'  ;
    }
    
    my $idx ;
    my ($track_fmt, $artist_html, $title_html, $mp3_html) ;
    my $track_num = 1 ;
    
    for($idx = 0 ; $idx <= $cddb{num_tracks} ; $idx++) {
        $artist_html = '' ;
        my ($title, $artist, $composer) = ($track_titles[$idx], $track_artists[$idx], $track_extras[$idx]) ;
        
        $composer =~ tr/\(\)//d ;

        if ($artist ne '') {
            my $links = TokenizeNames::tokenize_anchors_artist($artist) ;
            $artist_html = " - $links" ;
            $artist = "\t$artist" ; 	#for console mode
        } 
        
        my $composer_html = TokenizeNames::tokenize_anchors_composer($composer) ;
        
        if ($composer_html ne '') {
            $composer_html = " <i><small>($composer_html)</small></i>" ;
        }
        
        if($opt_html) {
            $title_html = '<b>' . TokenizeNames::tokenize_anchors_title($title) . '</b>' ;

            my $idx_1 = sprintf("%02d", $idx + 1) ;
            
            my $mp3_path = CddbMp3::find_mp3_file($cddb{artist}, $cddb{title}, $idx_1, $title) ;
            
            my $mp3_alink = '' ;

            if ( -f $mp3_path) { 
                $mp3_alink = '[<a href="' . $mp3_path . '">mp3</a>]' ;
            } else {
                #$mp3_alink = $mp3_path ;
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
    my $cddb_ref = shift ;
    my %cddb = %$cddb_ref ;
    
    my $artist = $cddb{artist} ;
    my $title  = $cddb{title} ;
    
    my $imgfile = $image_dir . $cddb_id . '.png' ;

    print '<div id="album_cover">' ;
    
    if(-f $imgfile) {		
        print "<img src=\"$imgfile\">" ;
    } else {
        my $cover_source_image_path = cover_source_image_path($artist, $title) ;
        
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
    my $cddb_ref = shift ;
    my %cddb = %$cddb_ref ;
    
    my $artist = $cddb{artist} ;
    my $title = $cddb{title} ;
    
    my $cover_path = cover_source_image_path($artist, $title) ;
    
    print '<div class="Debug"><code>' ;

    printbr %ENV ;
    
    printbr ("cddb-format.pl -t $infile") ;
    printbr ("kate $infile &") ;
    printbr ($cover_path) ;
    printbr ("$artist $title") ; 
    
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
	<li><a href="cddb-collection.pl?cddb=$genre_and_cddb">Add to collection</a>
	<li><a href="cddb-query.pl">Return to Query</a>
</ul>

</body>
</html>
EOF
    } else { 
        print "\n" ;
}
}
