package Data::Form::Elements;

use strict;
use warnings;

# we are wrapping Data::FormValidator to do our heavy lifting.  
# I am just trying to use as little code as possible to set a form
# up.
use Data::FormValidator;

=head1 Data::Form::Elements

Data::Form::Elements - a wrapper API for Data::FormValidator and a module for
providing elemental access to the fields of a form, from a generic
perspective.  The form in question does not need to be an HTML form.
Basically, if Data::FormValidator can use it as a form, so can we.

=head1 Version

Version 0.01

=cut
our $VERSION = '0.5';

=head1 Synopsis

A quick example of using this module for a login form:

    use Data::Form::Elements;

    my $form = Data::Form::Elements->new();

    # add a couple elements
    $form->add_element( "username", { 
        required => 1, errmsg => "Please provide your username." } );
    $form->add_element( "password", { 
        required => 1, errmsg => "Please provide your password." } );

    ...

    $form->validate( %ARGS );

    if ( $form->is_valid() ) {
        # continue logging on ...
    }

=head1 Functions

=head2 new()

Simple constructor.

=cut
sub new {
    my $class     = shift;
    # my $elements  = shift;
    # my $profile   = shift;	
  
    my $self  = {};
    
    # our form elements, their messages and values
    $self->{elements}   = {}; # $elements;

    # stash our validation profile
    $self->{profile}    = {}; # $profile;
    
    # use Data::Dumper;
   
    # make a placeholder for our validator
    $self->{validator}  = {};

    bless $self, $class;

    return $self;
}

=head2 add_element()

Add an element to the form object.
A full form element looks like this

    $form->add_element( "sort_position" , { 
        required => 0,
        valid  => 0,
        value => '',
        errmsg => 'Please choose where this section will show up on the list.',
        constratints => qr/^\d+$/,
        invmsg => 'Only numbers are allowed for this field.  Please use the dropdown to select the position for this section.' });
 
By default, only the name (key) is required.  the required element will
default to 0 if it is not specified.  If required is set to 1 and the
errmsg has not been initialized, it will also be set to a default.

=cut

sub add_element {
    my ( $self, $param_name, $param_details ) = @_;

    # get our elements hash
    my $elements = $self->{elements};

    unless ( exists $$param_details{required} ) {
	$$param_details{required} = 0;
    }
    
    if ( $$param_details{required} == 1 ) {
	    # do we have an error message set?
	    unless ( exists( $$param_details{errmsg} ) ) {
		$$param_details{errmsg} = "Please fill in this field.";
	    }
	    
    }
    # TODO: do we have an invalid message set?
    if ( exists $$param_details{constraints} ) {
	    # do we have an error message set?
	    unless ( exists( $$param_details{invmsg} ) ) {
		$$param_details{invmsg} = "The data for this field is in the wrong format.";
	    }
	    
    }

    # set up our default valid, value and message fields
    $$param_details{valid}	= 0;
    $$param_details{value}	= '';
    $$param_details{message}	= '';
    
    # put this element into our object's list.
    $$elements{ $param_name } = $param_details;
    
    # send our newly updated elements hash back to the object
    $self->{elements} = $elements;
    
}

=head2 params()

Returns a list of the elements in this form.

=cut
sub params {
    my ( $self ) = @_;

    my @params;

    my %constraints;
    foreach my $el ( keys %{$self->{elements}} ) {
        push @params, $el;
    }
    
    return @params;
}

=head2 dump_form()

use Data::Dumper to help debug a form.

=cut
sub dump_form {
    my ( $self ) = @_;

    use Data::Dumper;

    print Dumper( $self->{elements} );
}

=head2 dump_validator()

use Data::Dumper to help debug a form's underlying Data::FormValidator.

=cut
sub dump_validator {
    my ( $self ) = @_;

    use Data::Dumper;

    print Dumper( $self->{validator} );
}


=head2 validate()

Takes a hash of values for the form elements and validates them against the
rules you have set up.

Example:
    $form->validate( %ARGS );
    if ( $form->is_valid() ) {
        # continue processing form...
    }

=cut
sub validate {
    # pass $raw_form as a ref
    # TODO: enforce this, and add a carp.  :)
    my ( $self, %raw_form ) = @_;

    # pull in our elements
    my %elements = %{$self->{elements}};
    
    # build our profile for use with Data::FormValidator
    # TODO: make this its own internal (_buildProfile) function 
    my @required;
    my @optional;

    my %constraints;
    my %dependencies;

    foreach my $el ( keys %elements ) {

	if ( $elements{$el}{required} == 1 ) {
	    push @required, $el;
	} else {
	    push @optional, $el;
	}

	if ( exists $elements{$el}{constraints} ) {
	    $constraints{ $el } = $elements{$el}{constraints};
	}
	if ( exists $elements{$el}{dependencies} ) {
	    $dependencies{ $el } = $elements{$el}{dependencies};
	}        
    }
    
    my %profile = (
      required => [@required],
      optional => [@optional],
      filters => ['trim'],
      # TODO: make a constraints wrapper for each form element object.
      constraints => \%constraints,
      dependencies => \%dependencies
    );
    
    # populate our elements array with the new values from $raw_form
    my %form_els = %raw_form;

    foreach my $el ( keys %elements ) {
	# print "el: $el\n";
	# print "form_el: ", $form_els{$el}, "\n";

	$elements{$el}{value} = $form_els{$el};
    }

    
    # create our initial validator
    my $validator = Data::FormValidator->check( \%raw_form, \%profile );
    
    # check out our new values.
    # For instance, if we have 'trim' for a filter, then we want to be able to
    # get at that for use with future $form->param() calls
    foreach my $field ( keys %elements ) {
	# print "Our form : !", $elements{$field}{value}, "!\n";
	# print "Valid from Validator: !", $validator->{valid}{$field}, "!\n";
	# print "Invalid from Validator: !", $validator->{invalid}{$field}, "!\n";
	if ( exists $validator->{valid}{$field} ) {
	    $elements{$field}{value} = $validator->{valid}{$field};
	}
	if ( exists $validator->{invalid}{$field} ) {
	    # don't reset the value here, as D::FV will not preserve the data
	    # from an invalid field, except in an interal hash that we will
	    # not access.	
	    # $elements{$field}{value} = $validator->{invalid}{$field};
	}
    }
    
    # populate any relevant error messages
    if ( $validator->has_missing or $validator->has_invalid ) {
	# process the form elements, since we didn't pass
	# foreach my $field ( @{$self->{profile}{required}} ) {
	foreach my $field ( keys %elements ) {
	    if ( $validator->missing($field) ) {
		$self->{elements}{$field}{message} .= $self->{elements}{$field}{errmsg};
	    }
	    if ( $validator->invalid($field) ) {
		$self->{elements}{$field}{message} .= $self->{elements}{$field}{invmsg};
	    }
	}
    } 

    $self->{validator} = $validator;
}


=head2 is_valid()

Returns true/false.

=cut
sub is_valid {
    my ($self) = @_;

    my $valid = 0;
    
    # eval this, since we may not have a proper validator when this is called
    eval {
	unless ( $self->{validator}->has_missing or $self->{validator}->has_invalid ) {
	    $valid = 1;
	}
    };

    return $valid;
}


=head2 param()

Getter/Setter methods for setting an individual form element.

Example:
    # getter
    print $form->param("username");

    # setter
    $form->param("username", "jason");
    
TODO:  make accessors like Class::DBI so you will be able to do 
    $form->username();
or
    $form->username("jason");

=cut
sub param {
    my ($self, $element, $value) = @_;

    return unless defined($element);

    unless ( defined( $value ) ) {
	# just return the value
	return $self->{elements}{$element}{value};
    } else {
	# set a new value
	$self->{elements}{$element}{value} = $value;
    }
}

=head2 message()

returns the error or invalid message for a form element, if there is one.
Returns undef if no message exists.

=cut

sub message {
    my ($self, $element) = @_;

    return $self->{elements}{$element}{message};
}

=head1 Author

jason gessner, C<< <jason@multiply.o> >>

=head1 Bugs

Please report any bugs or feature requests to
C<bug-testing@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.  I will be notified, and then you'll automatically
be notified of progress on your bug as I make changes.

=head1 Copyright & License

Copyright 2004 me, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
