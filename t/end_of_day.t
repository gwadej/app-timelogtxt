#!/usr/bin/env perl

use Test::More tests => 6+1;
use Test::NoWarnings;

use strict;
use warnings;

use Time::Local;
use App::TimelogTxt;
use App::TimelogTxt::Day;
use App::TimelogTxt::Event;

my $log = <<'EOL';
2015-06-22 22:22:13 +Misc @Email
2015-06-22 22:29:01 stop
2015-06-22 22:36:24 +project @Code Foo module
2015-06-23 00:04:50 stop
2015-06-23 07:16:47 +Misc @Email
2015-06-23 07:29:07 stop
EOL

{
    package Mock::App;
    sub new { return bless {}, __PACKAGE__; }
    sub _logfile { return \$log; }
}

{
    my $app = Mock::App->new();
    my $summaries = App::TimelogTxt::extract_day_tasks( $app, "2015-06-22" );

    my $report = '';
    open my $out, '>', \$report or die "Unable to open output handle\n";
    $summaries->[0]->print_day_summary( $out );
    my $expected = <<'EOE';
2015-06-22  1:30
  Misc          0:07
  project       1:24
EOE
    is( $report, $expected, "One day: Summary is matches" );
}

{
    my $app = Mock::App->new();
    my $summaries = App::TimelogTxt::extract_day_tasks( $app, "2015-06-22", "2015-06-23" );

    my $report = '';
    open my $out, '>', \$report or die "Unable to open output handle\n";
    $summaries->[0]->print_day_summary( $out );
    my $expected = <<'EOE';
2015-06-22  1:30
  Misc          0:07
  project       1:24
EOE
    is( $report, $expected, "Two days: First summary matches" );
    $report = '';
    open $out, '>', \$report or die "Unable to open output handle\n";
    $summaries->[1]->print_day_summary( $out );
    $expected = <<'EOE';
2015-06-23  0:17
  Misc          0:12
  project       0:05
EOE
    is( $report, $expected, "Two days: Second summary matches" );
}


{
    my $app = Mock::App->new();
    my $summaries = App::TimelogTxt::extract_day_tasks( $app, "2015-06-22" );

    my $report = '';
    open my $out, '>', \$report or die "Unable to open output handle\n";
    $summaries->[0]->print_day_detail( $out );
    my $expected = <<'EOE';

2015-06-22  1:30
  Misc          0:07
    Email                0:07
  project       1:24
    Code                 1:24 (Foo module)
EOE
    is( $report, $expected, "One day: Summary is matches" );
}

{
    my $app = Mock::App->new();
    my $summaries = App::TimelogTxt::extract_day_tasks( $app, "2015-06-22", "2015-06-23" );

    my $report = '';
    open my $out, '>', \$report or die "Unable to open output handle\n";
    $summaries->[0]->print_day_detail( $out );
    my $expected = <<'EOE';

2015-06-22  1:30
  Misc          0:07
    Email                0:07
  project       1:24
    Code                 1:24 (Foo module)
EOE
    is( $report, $expected, "Two days: First summary matches" );
    $report = '';
    open $out, '>', \$report or die "Unable to open output handle\n";
    $summaries->[1]->print_day_detail( $out );
    $expected = <<'EOE';

2015-06-23  0:17
  Misc          0:12
    Email                0:12
  project       0:05
    Code                 0:05 (Foo module)
EOE
    is( $report, $expected, "Two days: Second summary matches" );
}

