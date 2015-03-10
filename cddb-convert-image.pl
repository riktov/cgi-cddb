#!/opt/local/bin/perl -w
# CGI to convert image file found in a separate directory to cddb web image 

use strict ;
use CGI ;
use Image::Magick ;

use Cddb ;

#globals
my $cddb_image_dir = "../cddb_images/" ;
#my $cddb_image_dir_thumb   = "${cddb_image_dir}thumbs/" ;
#my $cddb_image_dir_favicon = "${cddb_image_dir}favicon/" ;
my $opt_cgi = 1 ;

my $cgi = new CGI ;
$cgi->charset('utf-8') ;

my($cover_path, $cddb_path) ;

$cover_path = $cgi->param('source') ;
$cddb_path = $cgi->param('cddb') ;

#($cover_path, $cddb_path) = @ARGV ;

my $cddb_id = $cddb_path ;
$cddb_id =~ s|.+/|| ;

my $image_in = $cover_path ;
my $image_out ;

#convert image
my $image = Image::Magick->new ;
my $num_images ;
my $result ;

#main image
$num_images = $image->Read($image_in)  ;
print STDERR "The number of images read is: $num_images\n";

$image_out = $cddb_image_dir . $cddb_id . '.png' ;
print STDERR "The main file is: $image_out\n";
$image->Resize(geometry=>'300x300^') ;
$result = $image->Write($image_out)  ;
print STDERR "The result of Write is: $result\n" ;

#thumb
#$num_images = $image->Read($image_in)  ;
$image_out = $cddb_image_dir . "thumbs/" . $cddb_id . '_th.png' ;
#print STDERR "The thumb file is:" . $image_out ;
$image->Resize(geometry=>'32x32^') ;
$result = $image->Write($image_out)  ;
#print STDERR "The result of Write is:" . $result ;

#favicon
#$num_images = $image->Read($image_in)  ;
$image_out = $cddb_image_dir . "favicon/" . $cddb_id . '_favicon.png' ;
$image->Resize(geometry=>'16x16^') ;
$image->Write($image_out)  ;

undef $image ;

#print "Converted $image_in to $image_out" ;
#print '<p><a href="cddb-format.pl?' . $cddb_path . '">Return</a></p>' ;

my $cddb_genre_and_id = Cddb::genre_and_id($cddb_path) ;
exit print $cgi->redirect('cddb-format.pl?cddb=' . $cddb_genre_and_id );

#####################
## output only on error

#output status
if ($opt_cgi) {
#print $cgi->header ;
#print $cgi->start_html(-title=>'Converted Image',
#			 -style=>'../css/cddb.css',
#			 -script=>[
#					{ -type => 'text/javascript', -src => '../js/sorttable.js' }
#				]
#			) ;
}

#warn "$x" if "$x";      # print the error message
#$x =~ /(\d+)/;
#print $1;               # print the error number 
#print 0+$x;             # print the number of images read

#print $x . '<br>' . "\n";


if ($opt_cgi){
#    print $cgi->end_html ;
}
