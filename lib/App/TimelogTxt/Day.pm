package App::TimelogTxt::Day;

use warnings;
use strict;

our $VERSION = '0.03_1';

sub new {
    my ($class, $stamp) = @_;
    die "Missing required stamp.\n" unless $stamp;

    return bless {
        stamp => $stamp,
        start => undef,
        dur => 0,
        tasks => {},
        proj_dur => {},
    }, $class;
}

sub is_empty { return !$_[0]->{dur}; }

sub set_start {
    my ($self, $start) = @_;
    $self->{start} ||= $start;
    return;
}

sub update_dur {
    my ($self, $last, $epoch) = @_;
    my $curr_dur = $last->{epoch} ? $epoch - $last->{epoch} : 0;

    $self->{tasks}->{$last->{task}}->{dur} += $curr_dur if $last->{task};
    $self->{proj_dur}->{$last->{project}} += $curr_dur  if $last->{project};
    $self->{dur} += $curr_dur;

    return;
}

sub start_task {
    my ($self, $event) = @_;
    return if $event->is_stop();
    my $task = $event->task;
    return if $self->{tasks}->{$task};
    $self->{tasks}->{$task} = { start => $event->epoch, proj => $event->project, dur => 0 };
    return;
}

sub print_day_detail {
    my ($self, $fh) = @_;
    $fh ||= \*STDOUT;

    my ($tasks, $proj_dur) = @{$self}{ qw/tasks proj_dur/ };
    my $last_proj = '';

    print {$fh} "\n$self->{stamp} ", _format_dur( $self->{dur} ), "\n";
    foreach my $t ( sort { ($tasks->{$a}->{proj} cmp $tasks->{$b}->{proj}) || ($tasks->{$b}->{start} <=> $tasks->{$a}->{start}) }  keys %{$tasks} )
    {
        if( $tasks->{$t}->{proj} ne $last_proj )
        {
            printf {$fh} '  %-13s%s',  $tasks->{$t}->{proj}, _format_dur( $proj_dur->{$tasks->{$t}->{proj}} ). "\n";
            $last_proj = $tasks->{$t}->{proj};
        }
        my $task = $t;
        $task =~ s/\+\S+\s//;
        if ( $task =~ s/\@(\S+)\s*// )
        {
            if ( $task ) {
                printf {$fh} "    %-20s%s (%s)\n", $1, _format_dur( $tasks->{$t}->{dur} ), $task;
            }
            else {
                printf {$fh} "    %-20s%s\n", $1, _format_dur( $tasks->{$t}->{dur} );
            }
        }
        else {
            printf {$fh} "    %-20s%s\n", $task, _format_dur( $tasks->{$t}->{dur} );
        }
    }
    return;
}

sub print_day_summary {
    my ($self, $fh) = @_;
    $fh ||= \*STDOUT;

    my $proj_dur = $self->{proj_dur};

    print {$fh} "$self->{stamp} ", _format_dur( $self->{dur} ), "\n";
    foreach my $p ( sort keys %{$proj_dur} )
    {
        printf {$fh} '  %-13s%s',  $p, _format_dur( $proj_dur->{$p} ). "\n";
    }
    return;
}

sub print_hours {
    my ($self, $fh) = @_;
    $fh ||= \*STDOUT;

    my $proj_dur = $self->{proj_dur};

    print {$fh} $self->{stamp}, ': ', _format_dur( $self->{dur} ), "\n";
    return;
}

sub _format_dur
{
    my ($dur) = @_;
    $dur += 30; # round, don't truncate.
    return sprintf '%2d:%02d', int($dur/3600), int(($dur%3600)/60);
}

1;
__END__

=head1 NAME

App::TimelogTxt::Day - Class representing a day as a set of times, tasks, and
durations.

=head1 VERSION

This document describes ModName version 0.03_1

=head1 SYNOPSIS

    use App::TimelogTxt::Day;

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

App::TimelogTxt::Day requires no configuration files or environment variables.

=head1 DEPENDENCIES

None.

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

