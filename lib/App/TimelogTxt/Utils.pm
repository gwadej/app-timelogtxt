package App::TimelogTxt::Utils;

use warnings;
use strict;

use POSIX qw(strftime);
use Time::Local;

our $VERSION = '0.03';

my $LAX_DATE_RE  = qr<[0-9]{4}[-/](?:0[1-9]|1[0-2])[-/](?:0[1-9]|[12][0-9]|3[01])>;
my $TIME_RE      = qr<[01][0-9]:[0-5][0-9]:[0-6][0-9]>;

my $DATE_FMT     = '%Y-%m-%d';
my $DATETIME_FMT = "$DATE_FMT %T";
my $ONE_DAY      = 86400;
my $TODAY        = 'today';
my $YESTERDAY    = 'yesterday';
my @DAYS         = qw/sunday monday tuesday wednesday thursday friday saturday/;

sub TODAY    { return $TODAY; }
sub STOP_CMD { return 'stop'; }

sub parse_event_line
{
    my ($line) = @_;
    my ( $stamp, $time, $task ) = $line =~ m<\A
        ( $LAX_DATE_RE ) \s ( $TIME_RE )
        \s+(.*)          # the log entry
    \Z>x;
    die "Not a valid event line.\n" unless $stamp;
    return ( $stamp, $time, $task );
}

sub fmt_time
{
    my ( $time ) = @_;
    return strftime( $DATETIME_FMT, localtime $time );
}

sub fmt_date
{
    my ( $time ) = @_;
    return strftime( $DATE_FMT, localtime $time );
}

sub is_today
{
    my ($day) = @_;
    return (!$day or $day eq $TODAY);
}

sub today_stamp
{
    return App::TimelogTxt::Utils::fmt_date( time );
}

sub day_end
{
    my ( $stamp ) = @_;
    return App::TimelogTxt::Utils::fmt_date( stamp_to_localtime( $stamp ) + $ONE_DAY );
}

sub stamp_to_localtime
{
    my ( $stamp ) = @_;
    my @date = split /-/, $stamp;
    return unless @date == 3;
    $date[0] -= 1900;
    --$date[1];
    return timelocal( 59, 59, 23, reverse @date );
}

sub day_stamp
{
    my ( $day ) = @_;
    return today_stamp() if is_today( $day );

    # Parse the string to generate a reasonable guess for the day.
    return canonical_datestamp( $day ) if is_datestamp( $day );

    $day = lc $day;
    return unless grep { $day eq $_ } $YESTERDAY, @DAYS;

    my $now   = time;
    my $delta = 0;
    if( $day eq $YESTERDAY )
    {
        $delta = 1;
    }
    else
    {
        my $index = day_num_from_name( $day );
        return if $index < 0;
        my $wday = ( localtime $now )[6];
        $delta = $wday - $index;
        $delta += 7 if $delta < 1;
    }
    return fmt_date( $now - $ONE_DAY * $delta );
}

sub day_num_from_name
{
    my ($day) = @_;
    $day = lc $day;
    my $index = 0;
    foreach my $try ( @DAYS )
    {
        return $index if $try eq $day;
        ++$index;
    }
    return -1;
}

sub is_datestamp
{
    my ($stamp) = @_;
    return scalar ($stamp =~ m/\A$LAX_DATE_RE\z/);
}

sub canonical_datestamp
{
    my ($stamp) = @_;
    $stamp =~ tr{/}{-};
    return $stamp;
}

1;
__END__

=head1 NAME

ModName - [One line description of module's purpose here]


=head1 VERSION

This document describes ModName version 0.03


=head1 SYNOPSIS

    use ModName;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.
  
  
=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
ModName requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

=head1 AUTHOR

G. Wade Johnson  C<< wade@anomaly.org >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) <YEAR>, G. Wade Johnson C<< wade@anomaly.org >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

