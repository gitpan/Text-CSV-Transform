use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Text::CSV::Transform',
    license             => 'perl',
    dist_author         => 'Bharanee Rathna <deepfryed@gmail.com>',
    dist_version_from   => 'lib/Text/CSV/Transform.pm',
    build_requires => {
        'Test::More'       => 0,
        'Test::NoWarnings' => 0,
        'Text::CSV'        => 0,
        'YAML'             => 0,
        'File::Spec'       => 0,
        'FindBin'          => 0,
    },
    add_to_cleanup      => [ 'Text-CSV-Transform-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
