#!/usr/bin/env perl

use Test::More 'no_plan'; #tests => 1;
use Test::NoWarnings;
use Test::Exception;

use strict;
use warnings;

use App::TimelogTxt::Day;

throws_ok { App::TimelogTxt::Day->new } qr/Missing/, 'Bad new';

{
    my $label = 'Initial Object';

    my $day = App::TimelogTxt::Day->new( '2012-06-01' );
    isa_ok( $day, 'App::TimelogTxt::Day', '$day' );

    ok( $day->is_empty, "$label: empty before any items" );

    my $buffer = '';
    open my $fh, '>>', \$buffer or die "Unable to make file handle: $!\n";
    $day->print_day_detail( $fh );
    is( $buffer, "\n2012-06-01  0:00\n", "$label: print_day_detail" );

    $buffer = '';
    $day->print_day_summary( $fh );
    is( $buffer, "2012-06-01  0:00\n", "$label: print_day_summary" );

    $buffer = '';
    $day->print_hours( $fh );
    is( $buffer, "2012-06-01:  0:00\n", "$label: print_hours" );
}
