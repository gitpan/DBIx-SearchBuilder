# $Header: /raid/cvsroot/DBIx/DBIx-SearchBuilder/SearchBuilder/Handle/Oracle.pm,v 1.2 2000/08/30 18:46:49 jesse Exp $

package DBIx::SearchBuilder::Handle::Oracle;
use DBIx::SearchBuilder::Handle;
@ISA = qw(DBIx::SearchBuilder::Handle);

=head2 Connect

Connect takes a hashref and passes it off to SUPER::Connect;
it returns a database handle.

=cut
  
sub Connect {
    my $self = shift;
    
    $self->SUPER::Connect(@_);
    
    $self->dbh->{LongTruncOk}=1;
    $self->dbh->{LongReadLen}=8000;
    
    $self->dbh->SimpleQuery("ALTER SESSION set NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS'");
    
    return ($Handle); 
}
# }}}
=head1 NAME

  DBIx::SearchBuilder::Handle::Oracle -- an oracle specific Handle object

=head1 SYNOPSIS


  =head1 DESCRIPTION

=head1 AUTHOR

Jesse Vincent, jesse@fsck.com

=head1 SEE ALSO

perl(1), DBIx::SearchBuilder

=cut
