#!/usr/bin/perl -w

use strict ;

my $infile = shift ;
#create backup

my $opt_swap = 1 ;

#my (@track_titles, @track_artist) ;

my @numbers = (1, 2, 3, 4) ;
my @letters = ('a', 'b', 'c', 'd') ;

#foreach my $a, $b (@numbers, @letters) {
#    print "$a, $b\n" ;
#}
#exit ;

#slurp file into array

open INFILE, $infile or die ;
my @all_lines = <INFILE> ;
close INFILE ;

my @disc = grep /DTITLE=Various/i, @all_lines ;

if (!@disc) {
    print "Not a compilation disc\n" ;
    exit() ;
}

my @artist_lines = grep /TARTIST\d+=.+/,  @all_lines ;
my @title_lines  = grep /TTITLE\d+=.+/, @all_lines ;

#my @artist_name ;
my @title_name ;
my $line ;


#initialize artist name array from titles
my @artist_name = (('') x (@title_lines + 1)) ;

#insert existing artist names in to array;
foreach $line (@artist_lines) {
    if ($line =~ /TARTIST(\d+)=(.+)/) {
        $artist_name[$1] = $2 ;    
    } 
}

#print @title_lines ;
#print join "\n", @artist_name ;
#print "######################\n";

#exit ;

@artist_lines =() ;

my @title_lines_clipped ;

my ($new_artist_line, $new_title_line) ;

#clip titles and replace artist names
foreach $line (@title_lines) {
    my ($idx, $title, $artist) ;
    chomp $line ;
    
    if ($line =~ m|TTITLE(\d+)=(.+)|) {
        ($idx, $title) = ($1, $2) ;
        $new_title_line = $line  ;
        $new_artist_line = "TARTIST$idx=$artist_name[$idx]" ;
        push @title_lines_clipped, $new_title_line ;
        push @artist_lines, $new_artist_line ;        
    }

    if ($line =~ m|TTITLE(\d+)=(.+) / (.+)|) {
        ($idx, $title, $artist) = ($1, $2, $3) ;
        $title_lines_clipped[$idx] = "TTITLE$idx=$title"  ;

        if ($artist_name[$idx] eq '') {
            $artist_lines[$idx] = "TARTIST$idx=$artist" ;
        }
    }
}


#exit ;

my $is_in_list ;

$opt_swap = 1 ;

if ($opt_swap) {
    my @titles = @title_lines_clipped ;

    #http://www.perlmonks.org/index.pl?node_id=613280
    @title_lines_clipped = map { local $_ = $_ ; s/TARTIST/TTITLE/g ; $_ } @artist_lines ;    
    @artist_lines = map { local $_ = $_ ; s/TTITLE/TARTIST/g ; $_ } @titles ;
}

foreach $line (@all_lines) {
    if ($line =~ m/^TTITLE|^TARTIST/) {
        if (!$is_in_list) {
            $is_in_list = 1 ;

            print "\n" ;
            print join "\n", @title_lines_clipped ;
            print "\n\n" ;
            print join "\n", @artist_lines ;            
            print "\n\n" ;
        }
    } else {
        print $line ;
    }
}

