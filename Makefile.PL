use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'App::TimelogTxt',
    AUTHOR              => 'G. Wade Johnson <wade@cpan.org>',
    VERSION_FROM        => 'lib/App/TimelogTxt.pm',
    ABSTRACT_FROM       => 'lib/App/TimelogTxt.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Test::NoWarnings' => 0,
        'Test::Exception' => 0,
        'POSIX'    => 0,
        'Time::Local' => 0,
        'Getopt::Long' => 0,
        'Config::Tiny' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'App-TimelogTxt-*' },
);
