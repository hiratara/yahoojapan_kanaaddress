use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'WWW::YahooJapan::KanaAddress',
    license             => 'perl',
    dist_author         => 'Masahiro Honma <hiratara@cpan.org>',
    dist_version_from   => 'lib/WWW/YahooJapan/KanaAddress.pm',
    requires => {
        'Test::More' => 0,
        'version'    => 0,
        'LWP::UserAgent' => 0,
    },
    add_to_cleanup      => [ 'WWW-YahooJapan-KanaAddress-*' ],
    create_makefile_pl => 'passthrough',
    # create_readme => 1, 
);

$builder->create_build_script();
