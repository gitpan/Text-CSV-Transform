#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use File::Spec;
use lib File::Spec->catdir($FindBin::Bin, '../lib');

use Test::More tests => 6;
use Test::NoWarnings;

BEGIN {
    use_ok('Text::CSV::Transform');
}

my $transform = Text::CSV::Transform->new;

## test transforms in which a single output field is a function of a single
## input field.
$transform->load_data(
    File::Spec->catfile(
        $FindBin::Bin,
        'data/input1.csv'
    )
);
$transform->apply(
    File::Spec->catfile(
        $FindBin::Bin,
        'data/transform1.yaml'
    )
);
my $expected = do {
    local $/;
    open (FILE, File::Spec->catfile($FindBin::Bin, 'data/output1.csv')) || die $!;
    <FILE>;
};
is($transform->output, $expected, 'fields explode in transform correctly');

## test transforms in which a single output field is a function of more than
## one input field.
$transform->apply(
    File::Spec->catfile(
        $FindBin::Bin,
        'data/transform2.yaml'
    )
);
$expected = do {
    local $/;
    open (FILE, File::Spec->catfile($FindBin::Bin, 'data/output2.csv')) || die $!;
    <FILE>;
};
is($transform->output, $expected, 'fields combine in transform correctly');

## test cascaded transforms.
$transform->apply(
    File::Spec->catfile(
        $FindBin::Bin,
        'data/transform3.yaml'
    ),
    -cascade => 1,
);
$expected = do {
    local $/;
    open (FILE, File::Spec->catfile($FindBin::Bin, 'data/output3.csv')) || die $!;
    <FILE>;
};
is($transform->output, $expected, 'transform cascades correctly');

## test using string data directly.
$transform->load_data_from_string(<<CSV);
"address"
"742, Evergreen Terrace, Springfield, IL, USA"
CSV

$transform->apply_transform_from_string(<<YAML);
---
address:
  door:    sub { [split /, */, shift]->[0] }
  street:  sub { [split /, */, shift]->[1] }
  city:    sub { [split /, */, shift]->[2] }
  state:   sub { [split /, */, shift]->[3] }
  country: sub { [split /, */, shift]->[4] }

YAML

is(
    $transform->output,
    qq{"city","country","door","state","street"$/"Springfield","USA","742","IL","Evergreen Terrace"$/},
    'transforms work on string inputs'
);
