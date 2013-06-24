#!/usr/bin/env perl

use Test::Most tests => 15;
use Test::NoWarnings;

use App::TimelogTxt::Event;

dies_ok { App::TimelogTxt::Event->new_from_line() } "new_from_line dies with no argument.";
dies_ok { App::TimelogTxt::Event->new_from_line( 'This is not an event' ) } "new_from_line dies with bad argument.";

{
    my $label = 'Canonical event, line';
    my $line = '2013-06-05 10:00:02 +proj1 do something';
    my $event = App::TimelogTxt::Event->new_from_line( $line );
    isa_ok( $event, 'App::TimelogTxt::Event' );
    is( $event->stamp, '2013-06-05', "$label: stamp correct" );
    is( $event->project, 'proj1', "$label: project correct" );
    is( $event->task, '+proj1 do something', "$label: task correct" );
    is( $event->epoch, 1370444402, "$label: epoch correct" );
    is( $event->to_string, $line, "$label: string correct" );
}

{
    my $label = 'Canonical event, time';
    my $event = App::TimelogTxt::Event->new( '+proj1 do something', 1370444402 );
    isa_ok( $event, 'App::TimelogTxt::Event' );
    is( $event->stamp, '2013-06-05', "$label: stamp correct" );
    is( $event->project, 'proj1', "$label: project correct" );
    is( $event->task, '+proj1 do something', "$label: task correct" );
    is( $event->epoch, 1370444402, "$label: epoch correct" );
    is( $event->to_string, '2013-06-05 10:00:02 +proj1 do something', "$label: string correct" );
}
