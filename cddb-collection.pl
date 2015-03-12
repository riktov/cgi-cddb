#!/usr/bin/env perl -w
#
# cddb_add_db.pl
#
# Adds the specified CDDB to the database as "owned"


use strict ;
use CGI '-utf8';
use DBI ;

sub setup_db {
    my @drivers = DBI->available_drivers ;
    print join('<br/>', @drivers) ;

    my($user, $password, $db, $host) = ('paul', 'zard-blend', 'kuminso', 'localhost' ) ;
    
    my $dbh = DBI->connect("DBI:mysql:database=$db;host=$host",
                           $user, $password, {RaiseError => 1});

    print "$dbh->{mysql_clientinfo}\n";
    
    #sth means "statment handle
    my $sth = $dbh->prepare("SELECT * FROM `T_Item`");
    $sth->execute();

    my $row = $sth->fetchrow_hashref();

    print "The fetched row is [${row}]" ;
#{'Item_Label'} ;
}

####################################
## main starts here


## globals
my $doc_title = "CDDB Database Add" ;

my $cgi = new CGI ;
$cgi->charset('utf-8') ;

my $cddb_genre_and_id = $cgi->param('cddb') ;

print $cgi->header ;
print $cgi->start_html(-title=>$doc_title,
			 -style=>'../css/cddb.css',
			) ;


setup_db() ;

print $cgi->h1('Hello Collections') ;

$cgi->end_html ;

#exit print $cgi->redirect('cddb-format.pl?cddb=' . $cddb_genre_and_id );
## end of main
####################################
