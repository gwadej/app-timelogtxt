package App::TimelogTxt::Event;

use warnings;
use strict;
use Time::Local;
use App::TimelogTxt::Utils;

our $VERSION = '0.03_3';

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

    my ( $stamp, $time, $task ) = App::TimelogTxt::Utils::parse_event_line( $line );
    my ( $proj ) = $task =~ m/\+(\S+)/;
    $stamp       = App::TimelogTxt::Utils::canonical_datestamp( $stamp );
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

sub _date_time {
    my ($self) = @_;
    if( !defined $self->{_date_time} )
    {
        $self->{_date_time} = App::TimelogTxt::Utils::fmt_time( $self->{epoch} );
    }
    return $self->{_date_time};
}

sub stamp
{
    my ($self) = @_;
    $self->{stamp} ||= App::TimelogTxt::Utils::fmt_date( $self->{epoch} );
    return $_[0]->{stamp};
}

sub is_stop
{
    my ($self) = @_;
    return ($_[0]->{task} eq App::TimelogTxt::Utils::STOP_CMD());
}

1;
__END__

=head1 NAME

App::TimelogTxt::Event - Class representing an event to log.

=head1 VERSION

This document describes ModName version 0.03_1

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

=head1 CONFIGURATION AND ENVIRONMENT

App::TimelogTxt::Event requires no configuration files or environment variables.

=head1 DEPENDENCIES

Time:Local.

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

=head1 AUTHOR

G. Wade Johnson  C<< gwadej@cpan.org >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2013, G. Wade Johnson C<< gwadej@cpan.org >>. All rights reserved.

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

