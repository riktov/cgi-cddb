#!/usr/bin/perl -w
# CGI to convert image file found in a separate directory to cddb web image 

use strict ;
use CGI ;
use Image::Magick ;

#globals
my $cddb_image_dir = "../cddb_images/" ;
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
my $image_out = $cddb_image_dir . $cddb_id . '.png' ;

#convert image
my $image = Image::Magick->new ;
my $num_images ;

$num_images = $image->Read($image_in)  ;
$image->Resize(geometry=>'300x300^') ;
$image->Write($image_out)  ;

my $image_out_thumb = $image_out ;
$image_out_thumb =~ s/\.png$/_th.png/ ;

#$num_images = $image->Read($image_in)  ;
$image->Resize(geometry=>'32x32^') ;
$image->Write($image_out_thumb)  ;

my $image_out_favicon = $image_out ;
$image_out_favicon =~ s/\.png$/_favicon.png/ ;

#$num_images = $image->Read($image_in)  ;
$image->Resize(geometry=>'16x16^') ;
$image->Write($image_out_favicon)  ;

undef $image ;

#print "Converted $image_in to $image_out" ;
#print '<p><a href="cddb-format.pl?' . $cddb_path . '">Return</a></p>' ;


exit print $cgi->redirect('cddb-format.pl?' . $cddb_path );

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
