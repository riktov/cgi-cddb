package Cddb ;

require Exporter ;
@ISA = qw(Exporter) ;

@EXPORT=qw(
genre_and_id
artist_and_title
setup_mysql
) ;

sub genre_and_id {
	$fullpath = shift ;
	$fullpath =~ s|.*/(.+/.+)|$1| ;

	return $fullpath ;
}

#used when adding to collection database
sub artist_and_title {
    my $fullpath = shift ;
    
    open (INFILE, $fullpath) or die "Can't open file $fullpath\n";

    while ($line = <INFILE>) {
        if ($line =~ /DTITLE=(.+) \/ (.+)/) {
            $artist = $1 ;
            $title  = $2 ;      
            return ($artist, $title) ;
        }
    }
    return ("UNKNOWN", "UNKNOWN") ;
}

sub setup_mysql {
    my $dbh ;
    my @drivers = DBI->available_drivers ;
    #print join('<br/>', @drivers) ;

    my $cfg = new Config::Simple('.cddbrc') ;

    my $user     = $cfg->param('db_user') ;
    my $password = $cfg->param('db_password') ;
    my $database = $cfg->param('db_database') ;
    my $host     = $cfg->param('db_host') ;
    
    $dbh = DBI->connect("DBI:mysql:database=$database;host=$host",
                           $user, $password, {RaiseError => 1});

    #sth means "statment handle
    my $sth = $dbh->prepare("SELECT * FROM `T_CDs`");
    $sth->execute();

    my $row ;
    while($row = $sth->fetchrow_hashref()) {
    }

    return $dbh ;
}


#################################################
# Always put a return value in a module file
# http://dev.perl.org/perl6/rfc/269.html

1;

