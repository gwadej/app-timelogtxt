package App::TimelogTxt;

use warnings;
use strict;
use 5.010;

use autodie;
use App::CmdDispatch;
use Getopt::Long qw(:config posix_default);
use App::TimelogTxt::Utils;
use App::TimelogTxt::Day;
use App::TimelogTxt::File;
use App::TimelogTxt::Event;

our $VERSION = '0.03';


my %config = (
    editor => '',
    dir    => '',
    defcmd => '',
);
my $config_file = "$ENV{HOME}/.timelogrc";

my %commands = (
    'start' => {
        code     => \&start_event,
        clue     => 'start {event description}',
        abstract => 'Start timing a new event.',
        help     => 'Stop last event and start timing a new event.',
    },
    App::TimelogTxt::Utils::STOP_CMD() => {
        code => sub { my $app = shift; log_event( $app, App::TimelogTxt::Utils::STOP_CMD() ); },
        clue => App::TimelogTxt::Utils::STOP_CMD(),
        abstract => 'Stop timing last event.',
        help     => 'Stop timing last event.',
    },
    'push' => {
        code     => \&push_event,
        clue     => 'push {event description}',
        abstract => 'Save current event and start timing new.',
        help     => 'Save last event on stack and start timing new event.',
    },
    'pop' => {
        code     => \&pop_event,
        clue     => 'pop',
        abstract => 'Return to last pushed event.',
        help     => 'Stop last event and restart top event on stack.',
    },
    'drop' => {
        code     => \&drop_event,
        clue     => 'drop [all|{n}]',
        abstract => 'Drop items from stack.',
        help     => 'Drop one or more items from top of event stack, or all
if argument supplied.',
    },
    'ls' => {
        code     => \&list_events,
        clue     => 'ls [date]',
        abstract => 'List events.',
        help     => 'List events for the specified day. Default to today.',
    },
    'lsproj' => {
        code     => \&list_projects,
        clue     => 'lsproj',
        abstract => 'List known projects.',
        help     => 'List known projects.',
    },
    'lstk' => {
        code     => \&list_stack,
        clue     => 'lstk',
        abstract => 'Display items on the stack.',
        help     => 'Display items on the stack.',
    },
    'edit' => {
        code     => \&edit_logfile,
        clue     => 'edit',
        abstract => 'Edit the timelog file.',
        help     => 'Open the timelog file in the current editor',
    },
    'report' => {
        code     => \&daily_report,
        clue     => 'report [date [end date]]',
        abstract => 'Task report.',
        help     => 'Display a report for the specified days.',
    },
    'summary' => {
        code     => \&daily_summary,
        clue     => 'summary [date [end date]]',
        abstract => 'Short summary report.',
        help     => q{Display a summary of the appropriate days' projects.},
    },
    'hours' => {
        code     => \&report_hours,
        clue     => 'hours [date [end date]]',
        abstract => 'Hours report.',
        help     => q{Display the hours worked for each of the appropriate days.},
    },
);

{
    package Timelog::CmdDispatch;
    use base 'App::CmdDispatch';

    sub new
    {
        my $self = App::CmdDispatch::new( @_ );
        $self->init();
        return $self;
    }

    sub _logfile   { return $_[0]->get_config()->{'logfile'}; }
    sub _stackfile { return $_[0]->get_config()->{'stackfile'}; }

    sub init
    {
        my ($self) = @_;
        my $config = $self->get_config();

        $config->{editor} ||= $config{editor} || $ENV{'VISUAL'} || $ENV{'EDITOR'} || '/usr/bin/vim';
        $config->{dir}    ||= $config{dir} || "$ENV{HOME}/timelog";
        $config->{defcmd} ||= $config{defcmd} || App::TimelogTxt::Utils::STOP_CMD();
        $config->{'dir'} =~ s/~/$ENV{HOME}/;
        foreach my $d ( [qw/logfile timelog.txt/], [qw/stackfile stack.txt/] )
        {
            $config->{ $d->[0] } = "$config->{'dir'}/$d->[1]";
            $config->{ $d->[0] } =~ s/~/$ENV{HOME}/;
        }
        return;
    }
}

sub run
{
    GetOptions(
        "dir=s"    => \$config{'dir'},
        "editor=s" => \$config{'editor'},
        "conf=s"   => \$config_file,
    );

    my $options = {
        config           => $config_file,
        default_commands => 'help shell',
        'help:post_hint' =>
            "\nwhere [date] is an optional string specifying a date of the form YYYY-MM-DD
or a day name: yesterday, today, or sunday .. saturday.\n",
        'help:post_help' =>
            "\nwhere [date] is an optional string specifying a date of the form YYYY-MM-DD
or a day name: yesterday, today, or sunday .. saturday.\n",
    };
    my $app = Timelog::CmdDispatch->new( \%commands, $options );

    # Handle default command if none specified
    @ARGV = split / /, $app->get_config()->{'defcmd'} unless @ARGV;

    $app->run( @ARGV );

    return;
}

sub log_event
{
    my $app    = shift;
    open my $fh, '>>', $app->_logfile;
    my $event = App::TimelogTxt::Event->new( "@_", time );
    print {$fh} $event->to_string, "\n";
    return;
}

sub edit_logfile
{
    my ( $app ) = @_;
    system $app->get_config()->{'editor'}, $app->_logfile;
    return;
}

sub _each_logline
{
    my ( $app, $code ) = @_;
    open my $fh, '<', $app->_logfile;
    $code->() while( <$fh> );
    return;
}

sub list_events
{
    my ( $app, $day ) = @_;
    my $stamp = App::TimelogTxt::Utils::day_stamp( $day );

    _each_logline( $app, sub { print if 0 == index $_, $stamp; } );
    return;
}

sub list_projects
{
    my ( $app ) = @_;
    my %projects;
    _each_logline(
        $app,
        sub {
            my ( @projs ) = m/\+(\S+)/g;
            @projects{@projs} = ( 1 ) x @projs if @projs;
        }
    );
    print "$_\n" foreach sort keys %projects;
    return;
}

sub daily_report
{
    my ( $app, $day, $eday ) = @_;

    my $summaries = extract_day_tasks( $app, $day, $eday );

    foreach my $summary ( @{$summaries} )
    {
        $summary->print_day_detail( \*STDOUT );
    }
    return;
}

sub daily_summary
{
    my ( $app, $day, $eday ) = @_;

    my $summaries = extract_day_tasks( $app, $day, $eday );

    foreach my $summary ( @{$summaries} )
    {
        $summary->print_day_summary( \*STDOUT );
    }
    return;
}

sub report_hours
{
    my ( $app, $day, $eday ) = @_;

    my $summaries = extract_day_tasks( $app, $day, $eday );

    foreach my $summary ( @{$summaries} )
    {
        $summary->print_hours( \*STDOUT );
    }
    return;
}

sub extract_day_tasks
{
    my ( $app, $day, $eday ) = @_;

    my $stamp = App::TimelogTxt::Utils::day_stamp( $day );
    die "No day provided.\n" unless defined $stamp;
    my $estamp = App::TimelogTxt::Utils::day_end( $eday ? App::TimelogTxt::Utils::day_stamp( $eday ) : $stamp );
    my ( $summary, %last, @summaries );
    my $event;
    my $prev_stamp = '';

    open my $fh, '<', $app->_logfile;
    my $file = App::TimelogTxt::File->new( $fh, $stamp, $estamp );

    while( defined( $_ = $file->readline ) )
    {
        eval {
            $event = App::TimelogTxt::Event->new_from_line( $_ );
        } or next;
        if( $prev_stamp ne $event->stamp )
        {
            my $new_stamp = $event->stamp;
            if( $summary and !$event->is_stop() )
            {
                $summary->update_dur( \%last, $new_stamp );
                %last = ();
            }
            $summary = App::TimelogTxt::Day->new( $new_stamp );
            push @summaries, $summary;
            $prev_stamp = $new_stamp;
        }
        $summary->set_start( $event->epoch );
        $summary->update_dur( \%last, $event->epoch );
        $summary->start_task( $event );
        %last = ($event->is_stop() ? () : $event->snapshot );
    }

    return [] unless $summary;

    my $end_time = ( App::TimelogTxt::Utils::is_today( $day ) and !$event->is_stop() )
        ? time
        : App::TimelogTxt::Utils::stamp_to_localtime( $estamp );

    $summary->update_dur( \%last, $end_time );

    return if $summary->is_empty;

    return \@summaries;
}

sub start_event
{
    my ( $app, @event ) = @_;
    log_event( $app, @event );
    return;
}

sub _stack
{
    my ($app) = @_;
    require App::TimelogTxt::Stack;
    return App::TimelogTxt::Stack->new( $app->_stackfile );
}

sub push_event
{
    my ( $app, @event ) = @_;
    my $stack = _stack( $app );
    $stack->push( _get_last_event( $app ) );
    log_event( $app, @event );
    return;
}

sub pop_event
{
    my ( $app ) = @_;
    return unless -f $app->_stackfile;
    my $stack = _stack( $app );
    my $event = $stack->pop;
    die "Event stack is empty.\n" unless $event;
    log_event( $app, $event );
    return;
}

sub drop_event
{
    my ( $app, $arg ) = @_;
    return unless -f $app->_stackfile;
    my $stack = _stack( $app );
    $stack->drop( $arg );
    return;
}

sub list_stack
{
    my ($app) = @_;
    return unless -f $app->_stackfile;
    my $stack = _stack( $app );
    $stack->list();
    return;
}

sub _get_last_event
{
    my ( $app ) = @_;
    my $event_line;
    _each_logline( $app, sub { $event_line = $_; } );
    my $event = App::TimelogTxt::Event->new_from_line( $event_line );

    return $event->task;
}

1;
__END__

=head1 NAME

App::TimelogTxt - Core code for timelog utility.


=head1 VERSION

This document describes App::TimelogTxt version 0.03


=head1 SYNOPSIS

    use App::TimelogTxt;

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
  
App::TimelogTxt requires no configuration files or environment variables.


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

Please report any bugs or feature requests to
C<bug-app-timelogtxt@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

G. Wade Johnson  C<< <gwadej@cpan.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2013, G. Wade Johnson C<< <wade@cpan.org> >>. All rights reserved.

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
