#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Text::CSV::Transform' );
}

diag( "Testing Text::CSV::Transform $Text::CSV::Transform::VERSION, Perl $], $^X" );
