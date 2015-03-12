#!/usr/bin/perl -w
#
# cddb_add_db.pl
#
# Adds the specified CDDB to the database as "owned"


use strict ;
use CGI '-utf8';
use DBI ;

my $dbh ;

sub setup_db {
    my @drivers = DBI->available_drivers ;
    #print join('<br/>', @drivers) ;

    my($user, $password, $db, $host) = ('paul', 'ami-yumi-96', 'paul_cddb', 'localhost' ) ;
    
    $dbh = DBI->connect("DBI:mysql:database=$db;host=$host",
                           $user, $password, {RaiseError => 1});

    #print "$dbh->{mysql_clientinfo}\n";
    
    #sth means "statment handle
    my $sth = $dbh->prepare("SELECT * FROM `T_CDs`");
    $sth->execute();

    my $row ;
    while($row = $sth->fetchrow_hashref()) {
	#print "The fetched row is [${row}]" ;
#	print $$row{'CD_Title'} ;
    }
}

sub insert_cddb {
    my($artist, $title, $cddb_id) = @_ ;
    
    my $sql_statement = "INSERT INTO `T_CDs` (`CD_Artist`, `CD_Title`, `CD_ID`) VALUES (?, ?, ?)" ;
    #my ($artist, $title, $cddb) = ('Van Halen', '1984', '5d07d909') ;
    my $sth = $dbh->prepare($sql_statement) ;
    $sth->execute($artist, $title, $cddb_id) ;
}

####################################
## main starts here


## globals
my $doc_title = "CDDB Database Add" ;

my $cgi = new CGI ;
$cgi->charset('utf-8') ;

my $cddb_genre_and_id = $cgi->param('cddb') ;
my $artist  = $cgi->param('artist') ;
my $title   = $cgi->param('title') ;

setup_db() ;
my $cddb_id = $cddb_genre_and_id ;
$cddb_id =~ s|.+/|| ;

insert_cddb($artist, $title, $cddb_id) ;

exit print $cgi->redirect('cddb-format.pl?cddb=' . $cddb_genre_and_id );

print $cgi->header ;
print $cgi->start_html(-title=>$doc_title,
			 -style=>'../css/cddb.css',
			) ;


print $cgi->h1('Hello Collections') ;

$cgi->end_html ;


## end of main
####################################
