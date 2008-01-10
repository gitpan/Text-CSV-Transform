package Text::CSV::Transform;

use strict;
use warnings;

our $VERSION = '0.01';

use YAML ();
use Text::CSV ();

=head1 NAME

Text::CSV::Transform - Transform data based on a YAML template.

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

Text::CSV::Transform allows you to apply data transformations on data from a csv file
to produce another using a YAML based transformation template.

=head1 EXAMPLE

 use Text::CSV::Transform;

 my $transform = Text::CSV::Transform->new();
 $transform->load_data("input.csv");
 $transform->apply("transform1.yaml");
 $transform->save_data("output.csv");
 print $transform->output;

 $transform->load_data("input.csv");
 $transform->apply($_, -cascade => 1) for (qw(transform1.yaml transform2.yaml));
 print $transform->output;


 __END__

=head1 INPUT/OUTPUT formats

 If the input CSV is

 "field1","field2","field3"
 "foo bar","baz","and thats it"


 and the transform YAML is

 ---
 field1:
   field1: sub { [split / /, shift]->[0] }
   field2: sub { [split / /, shift]->[1] }
 field2:
   field3: sub { uc shift }
   field4: sub { lc shift }
 field3: field5

 then output CSV is

 "field1","field2","field3","field4","field5"
 "foo","bar","BAZ","baz","and thats it"


 or if the YAML transform is

 ---
 field1:
   field1:
     args:
       - field1
       - field2
     func: sub { [split / /, shift]->[0] . shift }
   field2: sub { [split / /, shift]->[1] }
 field2:
   field3: sub { uc shift }
   field4: sub { lc shift }
 field3: field5

 then the output CSV is

 "field1","field2","field3","field4","field5"
 "foobaz","bar","BAZ","baz","and thats it"


 A more real world'ish example is given an input CSV like

 "address"
 "742, Evergreen Terrace, Springfield, IL, USA"

 and a YAML transform like

 ---
 address:
   door:    sub { [split /, */, shift]->[0] }
   street:  sub { [split /, */, shift]->[1] }
   city:    sub { [split /, */, shift]->[2] }
   state:   sub { [split /, */, shift]->[3] }
   country: sub { [split /, */, shift]->[4] }

 the output CSV will be

 "city","country","door","state","street"
 "Springfield","USA","742","IL","Evergreen Terrace"

 NOTE: The output fields are alpha sorted, if you want a different sort order,
       then you can move the columns around using a Schwartzian transform.


=head1 TEMPLATE FORMAT

Expressed in a pseudo BNF, the format looks something like (of course the following needs to be in proper YAML format, indents and the lot),

 <INPUT_FIELD_NAME>::= <OUTPUT_FIELD_DESCRIPTIONS>
 <OUTPUT_FIELD_DESCRIPTIONS>::= <OUTPUT_FIELD_DESCRIPTION> <OUTPUT_FIELD_DESCRIPTIONS> | <EMPTY>
 <OUTPUT_FIELD_DESCRIPTION>::= <INPUT_FIELD_NAME> | <FUNC> | <FUNC_WITH_ARGS>
 <FUNC>::= sub { ... }
 <FUNC_WITH_ARGS>::= <ARGS> <FUNC>
 <ARGS> ::= <INPUT_FIELD_NAME> <ARGS> | <EMPTY>

The YAML requirements are that these be specified as hashes except <ARGS> which need to be specified as an array.


=head1 METHODS

=head2 new

Creates a new instance of Text::CSV::Transform

=head2 load_data([string])

Loads input data from a CSV file.

=head2 load_data_from_string([string])

Loads input data from the given string (CSV).

=head2 apply_transform_from_string([string], -cascade => [boolean])

Applies the transform specified in the YAML string. The optional -cascade parameter
forces the transform to be applied to output generated previously.

=head2 apply([string], -cascade => [boolean])

Applies the transform specified in the YAML file.  The optional -cascade parameter
forces the transform to be applied to output generated previously.

=head2 save_data([string])

Saves output data to a CSV file.

=head2 output

Returns the output CSV data as a string.

=cut

sub new {
    return bless { csv => Text::CSV->new({always_quote => 1}) }, shift;
}

sub load_data {
    my ($self, $file) = @_;
    open (FILE, $file) || die $!;
    $self->_set_input_fields(my $header = <FILE>);
    $self->{input_rows} = [];
    $self->_add_input_row($_) while (<FILE>);
    close(FILE);
}

sub load_data_from_string {
    my ($self, $data) = @_;
    my @data = split /\n+/, $data;
    $self->_set_input_fields(shift @data);
    $self->{input_rows} = [];
    $self->_add_input_row($_) for @data;
}

sub apply_transform_from_string {
    my ($self, $transform, %args) = @_;
    $self->{transform} = $self->_init_transform(YAML::Load($transform));
    $self->_apply(%args);
}

sub apply {
    my ($self, $file, %args) = @_;
    $self->{transform} = $self->_init_transform(YAML::LoadFile($file));
    $self->_apply(%args);
}

sub _apply {
    my ($self, %args) = @_;
    my $input_fields = $self->{input_fields};
    my $input_rows = $self->{input_rows};
    if ($args{-cascade}) {
        $input_fields = $self->{output_fields};
        $input_rows = $self->{output_rows};
    }
    $self->{output_fields} = undef;
    $self->{output_rows} = [];
    for my $row (@$input_rows) {
        my %data;
        @data{@$input_fields} = @$row;
        my $output = $self->_apply_transform(\%data);
        unless ($self->{output_fields}) {
            $self->{output_fields} = [sort keys %$output];
        }
        $self->_add_output_row([map { $output->{$_} } sort keys %$output]);
    }
}

sub save_data {
    my ($self, $file) = @_;
    open (my $fh, ">$file") || die $!;
    $self->{csv}->print($fh, $self->{output_fields});
    for my $row (@{$self->{output_rows}}) {
        $self->{csv}->print($fh, $row);
    }
    close($fh);
}

sub output {
    my $self = shift;
    my @output;
    $self->{csv}->combine(@{$self->{output_fields}}) || die 'cannot create output header';
    push @output, $self->{csv}->string;
    for my $row (@{$self->{output_rows}}) {
        $self->{csv}->combine(@$row) || die "Cannot create CSV out of @$row";
        push @output, $self->{csv}->string;
    }
    return join ("\n", @output) .  "\n";
}

sub _set_input_fields {
    my ($self, $header) = @_;

    my @fields = $self->{csv}->parse($header)
        ? $self->{csv}->fields
        : die "Text::CSV Cannot parse $header";

    $self->{input_fields} = \@fields;
}

sub _add_input_row {
    my ($self, $row) = @_;
    my @fields = $self->{csv}->parse($row)
        ? $self->{csv}->fields
        : die "Text::CSV Cannot parse $row";
    $self->{input_rows} ||= [];
    push @{$self->{input_rows}}, \@fields;
}

sub _add_output_row {
    my ($self, $row) = @_;
    $self->{output_rows} ||= [];
    push @{$self->{output_rows}}, $row;
}

sub _init_transform {
    my ($self, $t) = @_;
    if (ref $t eq 'HASH') {
        foreach my $key (keys %$t) {
            $t->{$key} = $self->_init_transform($t->{$key});
        }
        return $t;
    }
    elsif (!ref $t) {
        no strict;
        my $value = eval "$t";
        die $@ if $@;
        return $value;
    }
    return $t;
}

sub _apply_transform {
    my ($self, $data) = @_;
    my %output;

    for my $column (@{$self->{input_fields}}) {
        if (ref $self->{transform}->{$column} eq 'HASH') {
            foreach my $field (keys %{$self->{transform}->{$column}}) {
                my $t = $self->{transform}->{$column}->{$field};
                if (ref $t eq 'CODE') {
                    $output{$field} = &$t($data->{$column});
                }
                elsif (ref $self->{transform}->{$column}->{$field} eq 'HASH') {
                    my $sub = $t->{func} || die 'incorrect transform format, expecting code';
                    my @args = map { $data->{$_} } @{$t->{args}};
                    $output{$field} = &$sub(@args);
                }
                else {
                    $output{$field} =  $self->{transform}->{$column}->{$field};
                }
            }
        }
        else {
            $output{$self->{transform}->{$column}} = $data->{$column};
        }
    }
    return \%output;
}

=head1 AUTHOR

Bharanee Rathna, C<< <deepfryed at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-text-csv-transform at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Text-CSV-Transform>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Text::CSV::Transform


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Text-CSV-Transform>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Text-CSV-Transform>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Text-CSV-Transform>

=item * Search CPAN

L<http://search.cpan.org/dist/Text-CSV-Transform>

=back


=head1 ACKNOWLEDGEMENTS

This work was done during employer sponsored labs time at realestate.com.au. I wish
to thank the leadership team for taking the initiative and encouraging programmers
to innovate on their own terms.

=head1 COPYRIGHT & LICENSE

Copyright 2007 Bharanee Rathna, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Text::CSV::Transform
