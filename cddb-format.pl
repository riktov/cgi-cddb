#!/usr/bin/perl -w
#
# cddb-format.pl
#
# Prints a text format CDDB file in HTML with links to cddb query for titles and names

#use lib "$ENV{HOME}/lib/perl5" ;

#use lib "/opt/local/lib/perl5/site_perl/5.16.3" ;

use strict ;
use utf8 ;
use URL::Encode ;
use Config::Simple ;
use File::Basename ;
use Getopt::Std ;
use CGI '-utf8';
use DBI ;
use CGI::Carp qw(fatalsToBrowser) ;

use Cddb ;
use TokenizeNames ;
use CddbMp3 ;

use vars qw($opt_h $opt_t $opt_a) ;


#Declarations
sub read_cddb_stdin ;
sub print_header ;
sub print_artist_and_title ;
sub print_tracks ;
sub print_collection_status ;
sub print_debug_window ;
sub print_footer ;
sub print_cover_image ;
sub printbr ;

#http://localhost/~paul/music/Bill_Evans/Yesterday_I_Heard_The_Rain/03%20-%20My_Romance.mp3

## GLOBALS
my $is_cgi = 0 ;

#default configuration
my $cddb_dir = "/Users/paul/.cddbslave" ;
my $image_dir = "../cddb_images/" ;
my $album_covers_dir="../album_covers/" ;
#my @mp3_dirs = ('../ext_music/', '../music/') ;

#options
my $opt_html = 1 ;


################
## main starts here

my $cfg = new Config::Simple('.cddbrc') ;

$cddb_dir = $cfg->param('cddb_dir') ;
$image_dir = $cfg->param('image_dir') ;

$cddb_dir =~ s|/$|| ;
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
my $discid = (basename($genre_and_cddb))[0] ;

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
            -href=>"../cddb_images/favicon/${discid}_favicon.png",
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

print_artist_and_title(\%cddb_info);
print_tracks(\%cddb_info);
print_cover_image(\%cddb_info) if $opt_html ;
print_collection_status(\%cddb_info) ;
print_debug_window(\%cddb_info) ;
print_footer();

### end of main()
##############################################################################


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
	    ($artist, $title) = ($1, $2) ;      
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
	    ($num, $track) = ($1, $2) ;
	    $track_artists[$num] = $track ;
	}
	
	if ($line =~ /EXTT(\d+)=(.*)/) {
	    ($num, $track) = ($1, $2) ;
	    $track_extras[$num] = $track ;
	}	
    }
    $artist or die "Couldn't parse disc artist in $infile\n" ;
    
    close INFILE ;

    $cddb_disc{discid} = (basename($filepath))[0] ;
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
        $d_artist_fmt = $cgi->h2($d_artist_link) ;
        
        $d_image_thumb = $image_dir . "thumbs/" . $discid . "_th.png" ;
        
        $d_title_fmt  = $cgi->h1($title) ;

        #some of that confusing CGI-perl tag-fu
        print $cgi->div(
            {id=>"disc_title"},
            $d_artist_fmt,
            $cgi->div(
                $cgi->img(
                    {src=>"${d_image_thumb}"}
                ),
                $d_title_fmt)
            );
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
    my ($track_fmt, $title_html, $mp3_html) ;
    my $track_num = 1 ;
    
    for($idx = 0 ; $idx <= $cddb{num_tracks} ; $idx++) {
        my ($title, $artist, $composer) = 
            ($track_titles[$idx], $track_artists[$idx], $track_extras[$idx]) ;

        $composer =~ tr/\(\)//d ;        
        
        if($opt_html) {
            my $title_html = '<b>' . tokenize_anchors_title($title) . '</b>' ;
            my $artist_html = tokenize_anchors_artist($artist) ;
            my $composer_html = tokenize_anchors_composer($composer) ;

            if($title_html ne '') { 
                $title_html = "<b>$title_html</b>"
            } ;
            if($artist_html ne '') {
                $artist_html = " - $artist_html" ;
            }
            if($composer_html ne '') {
                $composer_html = " <i><small>($composer_html)</small></i>" ;   
            }            

            my $tracknum_str_1 = sprintf("%02d", $idx + 1) ;

            my $mp3_path = CddbMp3::find_mp3_file($cddb{artist}, 
                                                  $cddb{title}, 
                                                  $tracknum_str_1, 
                                                  $title) ;
            
            my $mp3_alink = '' ;

            if ( -f $mp3_path) { 
                $mp3_alink = '[<a href="' . $mp3_path . '">mp3</a>]' ;
            } else {
		#printf("Can't find mp3 $mp3_path<br/>") ;
                #$mp3_alink = $mp3_path ;
            }
            
            print '<li>' ;
            print "${title_html}${artist_html}${composer_html} ${mp3_alink}" ;
            print '</li>'  ;
        } else {
            print "$track_num $title\t$artist" ;
        }
        
        $track_num++ ;
    }
		
    if($opt_html) {
        print '</ol>' if $opt_html ;
        print '</div>' ;
    }
}

#return the path of the unprocessed album cover image, or '' if none
sub cover_source_image_path {
    my($artist, $album) = @_ ;

    #    my $path = "${artist}-${album}.jpg" ;
    my $path = "${artist}-${album}.png" ;
    $path =~ tr|[ '\&+;/#*:]|_| ;#replace illegal path characters

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
    
    my $imgfile = $image_dir . $discid . '.png' ;

    print '<div id="album_cover">' ;
    
    if(-f $imgfile) {		
        print "<img src=\"$imgfile\">" ;
    } else {
        my $cover_source_image_path = cover_source_image_path($artist, $title) ;
        
        my $cover_convert_link = '' ;

	my $cover_source_image_path_jpg = $cover_source_image_path ;
	
	$cover_source_image_path_jpg =~ s/png$/jpg/ ;
	
        if(-f $cover_source_image_path) {
            print $imgfile . "<br/>" ;
            $cover_convert_link = "<a href=cddb-convert-image.pl?source=${cover_source_image_path}&cddb=${infile}>Convert Cover Image</a>" ;
            print $cover_convert_link ;
	} elsif (-f $cover_source_image_path_jpg) {
            print $imgfile . "<br/>" ;
            $cover_convert_link = "<a href=cddb-convert-image.pl?source=${cover_source_image_path_jpg}&cddb=${infile}>Convert Cover Image</a>" ;
            print $cover_convert_link ;
	    
        } else {
            print '<input type="file">Input File</input><br/>' ;
            print "Copy the image file to:<br/>" ;
	    $cover_source_image_path =~ s/.png// ;
	    $cover_source_image_path =~ s|.+album_covers/|| ;
	    print ${cover_source_image_path} ;
        }
    }
    
    print '</div>' ;
    print '<br style="clear:both">' ;
}

sub printbr {
    my $line = shift ;
    print $line . '<br />' ;
}

sub print_collection_status {
    print '<div id="collection_status">' ;
    my $cddb_ref = shift ;
    my %cddb = %$cddb_ref ;

    my $dbh = setup_mysql($cfg) ;

    my $sql_statement = "SELECT * FROM `T_CDs` WHERE `CD_ID`=?" ;
    my $sth = $dbh->prepare($sql_statement) ;
    $sth->execute($cddb{discid}) ;

    my $rowref ;
    my $is_owned = 0 ;

    my $discid ;
    
    while($rowref = $sth->fetchrow_hashref()) {
        my %row = %$rowref ;
        $discid = $row{CD_ID} ;
        $is_owned = 1 ;
    }

    if($is_owned) {
        print("You own the disc $discid.") ;
    } else {
        print '<form method="POST" action="cddb-collection.pl">' ;

        print $cgi->input(
            {
                type => "hidden",
                name => 'cddb',
                value=>${genre_and_cddb}
            }) ;
        print $cgi->input(
            {
                type=>"submit",
                name=>"own_disc",
                value=>"I own this disc"
            }) ;
        print '</form>' ; 
    }
    
    print '</div>' ;
}

sub print_debug_window {
    my $cddb_ref = shift ;
    my %cddb = %$cddb_ref ;
    
    my $artist = $cddb{artist} ;
    my $title = $cddb{title} ;
    
    my $cover_path = cover_source_image_path($artist, $title) ;
    
    print '<div class="Debug"><code>' ;

    while (my($key, $val) = each(%ENV)) {
        #printbr("$key => $val") ;
    }
#    printbr %ENV ;
    
    printbr ("cddb-format.pl -t $infile") ;
    printbr ("kate $infile &") ;
    printbr ($cover_path) ;
    printbr ("$artist $title") ; 
    
    print '</code></div>' ;
    
}

sub print_footer()
{
    if($opt_html) {
        my($artist, $title) = ($cddb_info{artist}, $cddb_info{title}) ;
        
#        my $encoder = UR::Encode->new();
        
        $artist = URL::Encode::url_encode($artist) ;
        $title  = URL::Encode::url_encode($title) ;
        
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
	<li><a href="cddb-tartist.pl?cddb_path=$infile">Convert to TARTIST format</a></li>
	<li><a href="cddb-query.pl">Return to Query</a></li>
</ul>

</body>
</html>
EOF
    } else { 
        print "\n" ;
}
}
