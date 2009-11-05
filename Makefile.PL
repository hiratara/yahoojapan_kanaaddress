use inc::Module::Install;

name 'WWW-YahooJapan-KanaAddress';
all_from 'lib/WWW/YahooJapan/KanaAddress.pm';
readme_from 'lib/WWW/YahooJapan/KanaAddress.pm';

requires 'LWP::UserAgent';
build_requires 'Module::Install::Repository';
build_requires 'Module::Install::AuthorTests';
test_requires 'Test::More';

# XXX This doesn't seem to work in Module::Install 0.91 and CPAN 1.9402
# auto_include_dependent_dists;

tests 't/*.t';
author_tests 'xt';

auto_set_repository;

WriteAll;
