# $Header: /home/jesse/DBIx-SearchBuilder/history/SearchBuilder/Record/Cachable.pm,v 1.6 2001/06/19 04:22:32 jesse Exp $
# by Matt Knopp <mhat@netlag.com>

package DBIx::SearchBuilder::Record::CacheCache; 

use DBIx::SearchBuilder::Record; 
use base 'DBIx::SearchBuilder::Handle';
use Cache::MemoryCache;


my %_CACHES = (); 


# Function: new 
# Type    : class ctor
# Args    : see DBIx::SearchBuilder::Record::new
# Lvalue  : DBIx::SearchBuilder::Record::Cachable

sub new () { 
  my ($class, @args) = @_; 
  my $self = $class->SUPER::new (@args);


 
  if ($self->can(_CacheConfig)) { 
     $self->{'_CacheConfig'}=$self->_CacheConfig();
  }

    $self->_SetupCache();
  return ($self);
}

sub _KeyCache {
    my $self = shift;
    return($_CACHES{$self->_Handle->DSN."-KEYS"});

}
sub _Cache {
    my $self = shift;
    return($_CACHES{$self->_Handle->DSN});

}
sub _SetupCache {
    my $self = shift;
    $_CACHES{ $self->_Handle->DSN . "-KEYS" } = Cache::MemoryCache->new(
        {namespace          => $self->_Handle->DSN,
        default_expires_in => ($self->{'_CacheConfig'}->{'cache_for_sec' }||5)
          . " seconds",
        auto_purge_interval => "5 seconds",
        auto_purge_on_set   => 1,
        auto_purge_on_get   => 1 }
    );
    $_CACHES{ $self->_Handle->DSN } = Cache::MemoryCache->new(
    {        namespace          => $self->_Handle->DSN,
        default_expires_in => $self->{'_CacheConfig'}->{'cache_for_sec'}
          . " seconds",
        auto_purge_interval => "5 seconds",
        auto_purge_on_set   => 1,
        auto_purge_on_get   => 1
    });

}


# Function: LoadFromHash
# Type    : (overloaded) public instance
# Args    : See DBIx::SearchBuilder::Record::LoadFromHash
# Lvalue  : array(boolean, message)

sub LoadFromHash {
    my $self = shift;
    my ($rvalue, $msg) = $self->SUPER::LoadFromHash(@_);
    ## Check the return value, if its good, cache it! 
     $self->_store()  if ($rvalue);
    return($rvalue,$msg);
}

# Function: LoadByCols
# Type    : (overloaded) public instance
# Args    : see DBIx::SearchBuilder::Record::LoadByCols
# Lvalue  : array(boolean, message)

sub LoadByCols {
    my ( $self, %attr ) = @_;
    ## Generate the cache key
    my $cache_key =
      $self->_lookup_primary_cache_key(
        $self->_gen_alternate_cache_key(%attr) );
    $self->_fetch($cache_key) if ($cache_key);
    if ( $self->id ) {
        return ( 1, "Fetched from cache" );
    }
    else {
        ## Fetch from the DB!
        my ( $rvalue, $msg ) = $self->SUPER::LoadByCols(%attr);
        ## Check the return value, if its good, cache it!
        if ($rvalue) {
            ## Only cache the object if its okay to do so.
            $self->_store();
            $self->_KeyCache->set( $alternate_key,
                $self->_primary_cache_key );
        }
        return ( $rvalue, $msg );
    }
}


# Function: _Set
# Type    : (overloaded) public instance
# Args    : see DBIx::SearchBuilder::Record::_Set
# Lvalue  : ?

sub __Set () { 
  my ($self, %attr) = @_; 
  my (@return) =  $self->SUPER::__Set(%attr);
    $self->_store();
    return(@return);
}


# Function: Delete
# Type    : (overloaded) public instance
# Args    : nil
# Lvalue  : ?

sub Delete () { 
  my ($self) = @_; 
  my $cache_key = $self->_primary_cache_key();
  my (@return) =  $self->SUPER::Delete();
  $self->Cache->remove($cache_key);
    return(@return);
}







# Function: _fetch
# Type    : private instance
# Args    : string(cache_key)
# Lvalue  : 1
# Desc    : Get an object from the cache, and make self object that. 

sub _fetch () { 
  my ($self, $cache_key) = @_;
    my %data = $self->Cache->get($cache_key);
    $self->_deserialize($data);
}

sub _deserialize {
    my $self = shift;
    my $data = shift;
    foreach my $key  (keys %$data) {
        $self->{$key}  =  $data->{$key};
    }
  return(1); 
}

sub __Value {
 my $self = shift;
  my $field = shift;
    $self->_fetch( $self->_primary_cache_key);
   return($self->SUPER::__Value($field));


}



# Function: _store
# Type    : private instance
# Args    : string(cache_key)
# Lvalue  : 1
# Desc    : Stores self object in the cache. 

sub _store (\$) { 
  my $self = shift;
  $self->_Cache->set($self->_primary_cache_key, $self->_serialize);
  return(1);
}

sub _serialize {
    my $self = shift;
    return ( { values => $self->{'values'},
                table => $self->{'table'},
               fetched => $self->{'fetched'} });
}   


# Function: _gen_alternate_cache_key
# Type    : private instance
# Args    : hash (attr)
# Lvalue  : 1
# Desc    : Takes a perl hash and generates a key from it. 

sub _gen_alternate_cache_key {
    my ( $self, %attr ) = @_;
    my $cache_key = $self->Table() . ':';
    while ( my ( $key, $value ) = each %attr ) {
        $key   ||= '__undef';
        $value ||= '__undef';

        if ( ref($value) eq "HASH" ) {
            $value = ( $value->{operator} || '=' ) . $value->{value};
        }
        else {
            $value = "=" . $value;
        }
        $cache_key .= $key . $value . ',';
    }
    chop($cache_key);
    return ($cache_key);
}




# Function: _primary_cache_key 
# Type    : private instance
# Args    : none
# Lvalue: : 1
# Desc    : generate a primary-key based variant of self object's cache key
#           primary keys is in the cache 

sub _primary_cache_key {
    my $self = shift;

    return $self->{'primary_cache_key'}
      if ( exists $self->{'primary_cache_key'} );
    return undef unless ( $self->Id );

    my $primary_cache_key = $self->Table() . ':';
    my @attributes;
    foreach my $key ( @{ $self->_PrimaryKeys } ) {
        push @attributes, $key . '=' . $self->SUPER::__Value($key);
    }

    $primary_cache_key .= join( ',', @attributes );

    $self->{'primary_cache_key'} = $primary_cache_key;
    return ($primary_cache_key);

}

# Function: lookup_primary_cache_key 
# Type    : private class
# Args    : string(alternate cache id)
# Lvalue  : string(cache id)
sub _lookup_primary_cache_key {
    my $self          = shift;
    my $alternate_key = shift;  
    my $primary_key =  $self->_KeyCache->get($alternate_key );
    if ($primary_key) {
        return($primary_key);
    }
        # If the alternate key is really the primary one
    elsif ($self->_Cache->get($alternate_key)) {
        return ($alternate_key) 
    } 
    else {  # empty!
        return(undef);
    }
}


1;
