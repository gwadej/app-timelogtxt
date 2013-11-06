use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'App::TimelogTxt',
    AUTHOR              => 'G. Wade Johnson <gwadej@cpan.org>',
    VERSION_FROM        => 'lib/App/TimelogTxt.pm',
    ABSTRACT_FROM       => 'lib/App/TimelogTxt.pm',
    LICENSE             => 'perl',
    EXE_FILES           => [ 'bin/timelog' ],
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::Most'       => 0,
        'Test::NoWarnings' => 0,
        'POSIX'            => 0,
        'File::Path'       => 0,
        'Time::Local'      => 0,
        'Getopt::Long'     => 0,
        'Config::Tiny'     => 0,
        'autodie'          => 0,
        'App::CmdDispatch' => 0.41,
        'List::Util'       => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'App-TimelogTxt-*' },
    META_MERGE          => {
        resources => {
            repository => 'https://github.com/gwadej/app-timelogtxt',
        },
    },
);
