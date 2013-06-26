package mop::object;

use v5.16;
use warnings;

use mop::util    qw[ find_meta ];
use Scalar::Util qw[ blessed ];

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

sub new {
    my $class = shift;
    my %args  = @_;
    if ($class =~ /^mop::/) {
        bless \%args => $class;    
    } else {
        my $self = bless \(my $x) => $class;

        my @mro = @{ mop::mro::get_linear_isa($class) };

        my %attributes = map { 
            if (my $m = find_meta($_)) {
                %{ $m->attributes }
            }
        } reverse @mro;

        foreach my $attr (values %attributes) { 
            if ( exists $args{ $attr->key_name }) {
                $attr->store_data_in_slot_for( $self, $args{ $attr->key_name } )
            } else {
                $attr->store_default_in_slot_for( $self );
            }
        }

        foreach my $class (reverse @mro) {
            if (my $m = find_meta($class)) {
                $m->get_submethod('BUILD')->execute($self, [ \%args ]) 
                    if $m->has_submethod('BUILD');
            }
        }

        $self;
    }
}

sub DESTROY {
    my $self = shift;
    foreach my $class (@{ mop::mro::get_linear_isa($self) }) {
        if (my $m = find_meta($class)) {
            $m->get_submethod('DEMOLISH')->execute($self, []) 
                if $m->has_submethod('DEMOLISH');
        }
    }    
}

our $METACLASS;

sub metaclass {
    return $METACLASS if defined $METACLASS;
    require mop::class;
    $METACLASS = mop::class->new( 
        name       => 'mop::object',
        version    => $VERSION,
        authrority => $AUTHORITY,
    );
    $METACLASS->add_method( mop::method->new( name => 'new',       body => \&new ) );
    $METACLASS->add_method( mop::method->new( name => 'metaclass', body => \&metaclass ) );
    $METACLASS->add_method( mop::method->new( 
        name => 'isa', 
        body => sub {
            my ($self, $class) = @_;
            scalar grep { $class eq $_ } @{ mop::mro::get_linear_isa($self) }
        } 
    ));
    $METACLASS->add_method( mop::method->new( 
        name => 'can', 
        body => sub {
            my ($self, $method_name) = @_;
            if (my $method = mop::internals::mro::find_method($self, $method_name)) {
                return blessed($method) ? $method->body : $method;
            }
        } 
    ));
    $METACLASS->add_method( mop::method->new( name => 'DESTROY', body => \&DESTROY ) );
    $METACLASS;
}

1;

__END__