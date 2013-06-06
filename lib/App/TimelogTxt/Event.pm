package App::TimelogTxt::Event;

use warnings;
use strict;
use Time::Local;
use POSIX qw(strftime);
 
our $VERSION = '0.03';

my $LAX_DATE_RE  = qr<[0-9]{4}[-/][01][0-9][-/][0-3][0-9]>;
my $TIME_RE      = qr<[01][0-9]:[0-5][0-9]:[0-6][0-9]>;
my $DATE_FMT     = '%Y-%m-%d';
my $DATETIME_FMT = "$DATE_FMT %T";
my $ONE_DAY      = 86400;
my $TODAY        = 'today';
my $YESTERDAY    = 'yesterday';
my @DAYS         = qw/sunday monday tuesday wednesday thursday friday saturday/;

sub TODAY    { return $TODAY; }

sub is_datestamp
{
    my ($stamp) = @_;
    return scalar $stamp =~ m/^$LAX_DATE_RE$/;
}

sub canonical_datestamp
{
    my ($stamp) = @_;
    $stamp =~ tr{/}{-};
    return $stamp;
}

sub new
{
    my ($class, $task, $time) = @_;
    $time ||= time;
    my ( $proj ) = $task =~ m/\+(\S+)/;
    my $obj = {
        epoch => $time, task => $task, project => $proj
    };
    return bless $obj, $class;
}

sub new_from_line
{
    my ($class, $line) = @_;
    die "Not a valid event line.\n" unless $line;

    my ( $stamp, $time, $task ) = $line =~ m<^
        ( $LAX_DATE_RE ) \s ( $TIME_RE )
        \s+(.*)          # the log entry
    \Z>x;
    die "Not a valid event line.\n" unless $stamp;

    my ( $proj ) = $task =~ m/\+(\S+)/;
    $stamp       = canonical_datestamp( $stamp );
    my $datetime = "$stamp $time";
    my $obj = {
        stamp => $stamp, task => $task, project => $proj, _date_time => $datetime
    };
    return bless $obj, $class;
}

sub task    { return $_[0]->{task}; }
sub project { return $_[0]->{project}; }

sub to_string
{
    my ($self) = @_;
    return $self->_date_time . ' ' . $self->task;
}

sub epoch
{
    my ($self) = @_;
    if( !defined $self->{epoch} )
    {
        my @fields = split /[^0-9]/, $self->{_date_time};
        $fields[0] -= 1900;
        $fields[1] -= 1;
        $self->{epoch} = timelocal( reverse @fields );
    }
    return $self->{epoch};
}

sub _fmt_time
{
    my ( $time ) = @_;
    return strftime( $DATETIME_FMT, localtime $time );
}

sub _fmt_date
{
    my ( $time ) = @_;
    return strftime( $DATE_FMT, localtime $time );
}

sub _date_time {
    my ($self) = @_;
    if( !defined $self->{_date_time} )
    {
        $self->{_date_time} = _fmt_time( $self->{epoch} );
    }
    return $self->{_date_time};
}

sub stamp_to_localtime
{
    my ( $stamp ) = @_;
    my @date = split /-/, $stamp;
    return unless @date == 3;
    $date[0] -= 1900;
    --$date[1];
    return Time::Local::timelocal( 59, 59, 23, reverse @date );
}

sub today_stamp
{
    return _fmt_date( time );
}

sub day_end
{
    my ( $stamp ) = @_;
    return _fmt_date( stamp_to_localtime( $stamp ) + $ONE_DAY );
}

sub stamp
{
    my ($self) = @_;
    if( !defined $self->{stamp} )
    {
        $self->{stamp} = strftime( $DATE_FMT, localtime $self->{epoch} );
    }
    return $_[0]->{stamp};
}

sub is_today
{
    my ($day) = @_;
    return (!$day or $day eq $TODAY);
}

sub day_stamp
{
    my ( $day ) = @_;
    return App::TimelogTxt::Event::today_stamp() if is_today( $day );

    # Parse the string to generate a reasonable guess for the day.
    return App::TimelogTxt::Event::canonical_datestamp( $day )
        if App::TimelogTxt::Event::is_datestamp( $day );

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
    return _fmt_date( $now - $ONE_DAY * $delta );
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

sub is_task
{
    my ($self, $task) = @_;
    return ($task && $_[0]->{task} eq $task);
}

sub snapshot
{
    my ($self) = @_;
    return %{$self};
}

1;
__END__

=head1 NAME

ModName - [One line description of module's purpose here]


=head1 VERSION

This document describes ModName version 0.0.3


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

