#!/usr/bin/env perl

use Test::More 'no_plan'; #tests => 1;
use Test::Exception;

use strict;
use warnings;

use App::TimelogTxt::File;

throws_ok { App::TimelogTxt::File->new(); } qr/required file handle/, 'Handles missing file handle';
throws_ok { App::TimelogTxt::File->new( 'file', ); } qr/required start/, 'Handles missing start marker';
throws_ok { App::TimelogTxt::File->new( 'file', '2012/06/07' ); } qr/required end/, 'Handles missing end';

my $filebuffer = <<EOF;
2012/01/01  junk
2012/01/01  junk
2012/01/01  junk
2012/01/01  junk
2012/01/01  junk
2012/01/01  junk
2012/01/01  junk
2012/06/01  data
2012/06/01  more
2012/06/02  middle
2012/06/02  another
2012/06/03  end
2012/06/03  more end
2012/06/04  after
EOF

open( my $fh, '<', \$filebuffer ) or die "Failed to make fake filehandle\n";
my $file = App::TimelogTxt::File->new( $fh, '2012/06/01', '2012/06/03' );

is( $file->readline, "2012/06/01  data\n", 'Correct first line' );
is( $file->readline, "2012/06/01  more\n", 'Correct second line' );
is( $file->readline, "2012/06/02  middle\n", 'Not on first tag' );
is( $file->readline, "2012/06/02  another\n", 'Still not on first tag' );
ok( !defined $file->readline, 'Report file end on end tag' );
ok( !defined $file->readline, ' ... For ever after' );

