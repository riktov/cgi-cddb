package CddbMp3 ;

# functions to support links to locally stored MP3s from the cddb-query web application

require Exporter ;

@ISA = qw(Exporter) ;

@EXPORT = qw(
find_mp3_file
) ;

use strict ;

my @mp3_dirs ;

my $cfg = new Config::Simple('.cddbrc') ;

@mp3_dirs = split(':', $cfg->param('mp3_dir_paths')) ;

#return the first valid path for a mp3 file in the mp3 directories
sub find_mp3_file {
    my($artist, $album, $tracknum_1based, $title) = @_ ;

    #mogrify the strings
#    my $tracknum_str = sprintf("%02d", $tracknum + 1) ;
#    my $uri = URI::Encode->new( { encode_reserved => 0 } );

    #We want to filter out the forward slash here, but leave it in for the actual path
    $album  = as_legal_filepath($album) ;
    $artist = as_legal_filepath($artist) ;
    $title  = as_legal_filepath($title) ;

    #print ("find_mp3_file()") ;
    #print @mp3_dirs ;

    my $mp3_path = '';
    
    foreach my $dir (@mp3_dirs) {
	#print "Looking for mp3 in $dir..." ;
        $mp3_path = "${dir}/$artist/$album/$tracknum_1based - ${title}.mp3" ;

        #print "Looking for $mp3_path<br/>" ;
        
        if (-f $mp3_path) { 
            return $mp3_path ;
        } 
    }
    return $mp3_path  ;#last unsuccessful attempt
}

sub as_legal_filepath {
    my $str = shift ;
    $str =~ s|[ '\?\!/]|_|g ;
    return $str ;
}

#################################################
# Always put a return value in a module file
# http://dev.perl.org/perl6/rfc/269.html

1;
