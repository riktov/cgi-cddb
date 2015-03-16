#!/usr/bin/perl -w
# CGI to convert image file found in a separate directory to cddb web image 

use strict ;
use CGI ;
use CGI::Carp ;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
use Image::Magick ;
use File::Basename ;

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

my @parts = fileparse($cddb_path) ;
my $discid = $parts[0] ;

my $image_in = $cover_path ;
my $image_out = '' ;

#convert image
my $image = Image::Magick->new ;

my $result ;

my $num_images = $image->Read($image_in)  ; #return value from Read() and Write() are unreliable

print STDERR "The number of images read from $image_in is: ${num_images}\n";

my %image_specs_of =
(
    main => ['', '', 300],
    thumbs => ['thumbs/', '_th', 32],
    favicon => ['favicon/', '_favicon', 16]
) ;

while(my($spec_label, $specs_ref) = each %image_specs_of) {
    my @specs = @$specs_ref ;

    my ($subdir, $suffix, $width) = @specs ;
    
    my $image_out = $cddb_image_dir . $subdir . $discid . $suffix . '.png' ;
    print STDERR "The $spec_label file is: $image_out\n";

    my $dimensions = "${width}x${width}^" ;
    
    $image->Resize(geometry=>$dimensions) ;
    $result = $image->Write($image_out)  ;

    print STDERR "[$result] images written to $image_out.\n" ;
}

undef $image ;
exit print $cgi->redirect($cgi->referer());

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
