package App::TimelogTxt;

use warnings;
use strict;
use 5.010;

use Carp;
use POSIX qw(strftime);
use Time::Local;
use Getopt::Long qw(:config posix_default);
use Config::Tiny;
use App::TimelogTxt::Day;
use App::TimelogTxt::File;

our $VERSION = '0.003';

my %config = (
    editor => '',
    client => '',
    dir => '',
    defcmd => '',
);
my $config_file = "$ENV{HOME}/.timelogrc";

my %commands = (
    'start'   => {
        code => \&log_event,
        synopsis => 'start {event description}',
        help => 'Stop last event and start timing a new event.',
    },
    'stop'    => {
        code => sub { log_event( 'stop' ); },
        synopsis => 'stop',
        help => 'Stop timing last event.',
    },
    'push'    => {
        code => \&push_event,
        synopsis => 'push {event description}',
        help => 'Save last event on stack and start timing new event.',
    },
    'pop'     => {
        code => \&pop_event,
        synopsis => 'pop',
        help => 'Stop last event and restart top event on stack.',
    },
    'drop'    => {
        code => \&drop_event,
        synopsis => 'drop [all|{n}]',
        help => 'Drop one or more items from top of event stack or all if argument supplied.',
    },
    'nip'    => {
        code => \&nip_event,
        synopsis => 'nip',
        help => 'Drop one item from under the top of event stack.',
    },
    'ls'      => {
        code => \&list_events,
        synopsis => 'ls [date]',
        help => 'List events for the specified day. Default to today.',
    },
    'lsproj'  => {
        code => \&list_projects,
        synopsis => 'lsproj',
        help => 'List known projects.',
    },
    'lstk'    => {
        code => \&list_stack,
        synopsis => 'lstk',
        help => 'Display items on the stack.',
    },
    'edit'    => {
        code => sub { system $config{'editor'}, $config{'logfile'}; },
        synopsis => 'edit',
        help => 'Open the timelog file in the current editor',
    },
    'help'    => {
        code => \&usage,
        synopsis => 'help [commands|aliases]',
        help => 'A list of commands and/or aliases. Limit display with the argument.',
    },
    'report'  => {
        code => \&daily_report,
        synopsis => 'report [date]',
        help => 'Display a report for the specified day.',
    },
    'summary' => {
        code => \&daily_summary,
        synopsis => 'summary [date]',
        help => q{Display a summary of the appropriate day's projects.},
    },
);

sub run {
    GetOptions(
        "dir=s" => \$config{'dir'},
        "client=s" => \$config{'client'},
        "editor=s" => \$config{'editor'},
        "conf=s"   => \$config_file,
    );

    %config = initialize_configuration( $config_file );

    # Handle default command if none specified
    @ARGV = split / /, ($config{'defcmd'}||'stop') unless @ARGV;

    # Handle alias if one is supplied
    my $cmd = shift @ARGV;
    if( exists $config{'alias'}->{$cmd} ) {
        ($cmd, @ARGV) = ((split / /, $config{'alias'}->{$cmd}), @ARGV);
    }

    # Handle builtin commands
    if ( exists $commands{$cmd} ) {
        $commands{$cmd}->{'code'}->( @ARGV );
    }
    else {
        print "Unrecognized command '$cmd'\n\n";
        usage();
    }
}

sub today_stamp {
    return strftime( '%Y-%m-%d', localtime time );
}

sub day_stamp {
    my ($day) = @_;
    return today_stamp() if !$day or $day eq 'today';
    return $day if $day =~ s!^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$!$1-$2-$3!;
    my $now = time;
    my $delta = 0;
    if( $day eq 'yesterday' ) {
        $delta = 1;
    }
    else {
        my $wday = (localtime $now)[6];
        my $index = 0;
        foreach my $try (qw/sunday monday tuesday wednesday thursday friday saturday/) {
            last if $try eq lc $day;
            ++$index;
        }
        return if $index > 6;
        $delta = $wday - $index;
        $delta+=7 if $delta < 1;
    }
    return strftime( '%Y-%m-%d', localtime $now-86400*$delta ) if $delta;
    # Parse the string to generate a reasonable guess for the day.
}

sub log_event {
    open my $fh, '>>', $config{'logfile'} or die "Cannot open timelog ($config{'logfile'}): $!\n";
    print {$fh} strftime( '%Y-%m-%d %T', localtime time ), " @_\n";
    return;
}

sub initialize_configuration {
    my ($config_file) = @_;
    my $conf = -f $config_file ? Config::Tiny->read( $config_file ) : {};

    delete @config{grep { !$config{$_} } keys %config};
    %config = (
        editor => $ENV{'VISUAL'} || $ENV{'EDITOR'} || '/usr/bin/vim',
        client => 'cPanel',
        dir => "$ENV{HOME}/timelog",
        defcmd => 'stop',
        ($conf->{_} ? %{$conf->{_}} : ()),
        ($conf->{'alias'} ? ('alias'=>$conf->{'alias'}) : ()),
        %config
    );
    $config{'dir'} =~ s/~/$ENV{HOME}/;
    foreach my $d (([qw/logfile timelog.txt/], [qw/stackfile stack.txt/], [qw/reportfile report.txt/], [qw/archive archive.txt/])) {
        $config{$d->[0]} = "$config{'dir'}/$d->[1]";
        $config{$d->[0]} =~ s/~/$ENV{HOME}/;
    }
    return %config;
}


sub usage {
    my ($arg) = @_;
    if( !$arg or $arg eq 'commands' ) {
        print "\nCommands:\n";
        foreach my $c (sort keys %commands) {
            my $d = $commands{$c};
            print "$d->{synopsis}\n        $d->{help}\n";
        }
        print "\nwhere [date] is an optional string specifying a date of the form YYYY-MM-DD
or a day name: yesterday, today, or sunday .. saturday.\n";
    }
    if( !$arg or $arg eq 'aliases' ) {
        print "\nAliases:\n";
        foreach my $c ( sort keys %{$config{'alias'}} )
        {
            print "$c\t: $config{'alias'}->{$c}\n";
        }
    }
}

sub list_events {
    my ($day) = @_;
    $day ||= 'today';
    my $stamp = day_stamp( $day );

    open( my $fh, '<', $config{'logfile'} ) or die "Unable to open time log file: $!\n";
    while(<$fh>)
    {
        print if 0 == index $_, $stamp;
    }
    return;
}

sub list_projects {
    open( my $fh, '<', $config{'logfile'} ) or die "Unable to open time log file: $!\n";
    my %projects;
    while(<$fh>)
    {
        my (@projs) = m/\+(\S+)/g;
        @projects{@projs} = (1) x @projs if @projs;
    }
    print "$_\n" foreach sort keys %projects;
    return;
}

sub daily_report {
    my ($day,$eday) = @_;

    my $summaries = extract_day_tasks( $day, $eday );

    foreach my $summary (@{$summaries})
    {
        $summary->print_day_detail( \*STDOUT );
    }
    return;
}

sub daily_summary {
    my ($day) = @_;

    my $summaries = extract_day_tasks( $day );

    foreach my $summary (@{$summaries})
    {
        $summary->print_day_summary( \*STDOUT );
    }
    return;
}

sub extract_day_tasks {
    my ($day,$eday) = @_;
    $day ||= 'today';

    my $stamp = day_stamp( $day );
    my $estamp = $eday ? _day_end( day_stamp( $eday ) ) : _day_end( $stamp );
    my ($summary, %last, @summaries);
    my $task = '';
    my $prev_stamp = '';

    open( my $fh, '<', $config{'logfile'} ) or die "Unable to open time log file: $!\n";
    my $file = App::TimelogTxt::File->new( $fh, $stamp, $estamp );

    while( defined( $_ = $file->readline ) )
    {
        chomp;

        next unless my ($new_stamp, @fields) = m{^
            (                             # the whole stamp
                (\d+)[-/](\d+)[-/](\d+)   # date pieces
            )
            \s(\d+):(\d+):(\d+)           # the time pieces
            \s+(.*)                       # the log entry
        $}x;
        if($prev_stamp ne $new_stamp)
        {
            if( $summary and $task ne 'stop' ) {
                $summary->update_dur( \%last, $new_stamp );
                %last = ();
            }
            $summary = App::TimelogTxt::Day->new( $new_stamp, $config{'client'} );
            push @summaries, $summary;
            $prev_stamp = $new_stamp;
        }
        $fields[0] -= 1900;
        $fields[1] -= 1;
        $task = pop @fields;
        my ($proj) = $task =~ /\+(\S+)/;
        my $epoch = timelocal( reverse @fields );
        $summary->set_start( $epoch );

        $summary->update_dur( \%last, $epoch );

        if ( $task eq 'stop' )
        {
            %last = ();
        }
        else
        {
            $summary->start_task( $task, $epoch, $proj );
            @last{qw/task epoch proj/} = ( $task, $epoch, $proj );
        }
    }

    return [] unless $summary;

    if ( $day eq 'today' and $task ne 'stop' )
    {
        $summary->update_dur( \%last, time );
    }
    else
    {
        $summary->update_dur( \%last, _stamp_to_localtime( $estamp ) );
    }

    return if $summary->is_empty;

    return \@summaries;
}

sub _stamp_to_localtime {
    my ($stamp) = @_;
    my @date = split /-/, $stamp;
    return unless @date == 3;
    $date[0] -= 1900;
    --$date[1];
    return Time::Local::timelocal( 59, 59, 23, reverse @date );
}

sub _day_end {
    my ($stamp) = @_;
    return strftime( '%Y-%m-%d', localtime( _stamp_to_localtime( $stamp ) + 86400) );
}

sub push_event {
    {
        open my $fh, '>>', $config{'stackfile'} or die "Unable to write to stack file: $!\n";
        print {$fh} _get_last_event(), "\n";
    }
    log_event( @_ );
}

sub pop_event {
    return unless -f $config{'stackfile'};
    my $event = _pop_stack();
    die "Event stack is empty.\n" unless $event;
    log_event( $event );
}

sub drop_event {
    my $arg = shift;
    return unless -f $config{'stackfile'};
    if( !defined $arg )
    {
        _pop_stack();
    }
    elsif( lc $arg eq 'all' )
    {
        unlink $config{'stackfile'};
    }
    elsif( $arg =~ /^[0-9]+$/ )
    {
        _pop_stack() foreach 1..$arg;
    }
}

sub nip_event {
    return unless -f $config{'stackfile'};
    _nip_stack();
}

sub _nip_stack {
    return unless -f $config{'stackfile'};
    open my $fh, '+<', $config{'stackfile'} or die "Unable to modify stack file: $!\n";
    my ($prevpos, $lastpos, $lastline);
    my ($pos, $line);
    while( my ($line, $pos) = _readline_pos( $fh ) ) {
        $prevpos = $lastpos if defined $lastpos;
        ($lastpos, $lastline) = ($pos, $line);
    }
    return unless defined $lastline;
    seek( $fh, $prevpos, 0 );
    print {$fh} $lastline;
    truncate( $fh, tell $fh );
    chomp $lastline;
    return $lastline;
}

sub _pop_stack {
    return unless -f $config{'stackfile'};
    open my $fh, '+<', $config{'stackfile'} or die "Unable to modify stack file: $!\n";
    my ($lastpos, $lastline);
    my ($pos, $line);
    while( my ($line, $pos) = _readline_pos( $fh ) ) {
        ($lastpos, $lastline) = ($pos, $line);
    }
    return unless defined $lastline;
    seek( $fh, $lastpos, 0 );
    truncate( $fh, $lastpos );
    chomp $lastline;
    return $lastline;
}

sub list_stack {
    return unless -f $config{'stackfile'};
    open my $fh, '<', $config{'stackfile'} or die "Unable to read stack file: $!\n";
    my @lines = <$fh>;
    @lines = reverse @lines if @lines > 1;
    print @lines;
    return;
}

sub _readline_pos {
    my $fh = shift;
    my $pos = tell $fh;
    my $line = <$fh>;
    return ($line, $pos) if defined $line;
    return;
}

sub _get_last_event {
    open( my $fh, '<', $config{'logfile'} ) or die "Unable to open time log file: $!\n";
    my $event_line;
    $event_line = $_ while <$fh>;
    chomp $event_line;
    $event_line =~  s{^(\d+)[-/](\d+)[-/](\d+)\s(\d+):(\d+):(\d+)\s+}{}; # strip timestamp

    return $event_line;
}

1;
__END__

=head1 NAME

App::TimelogTxt - [One line description of module's purpose here]


=head1 VERSION

This document describes App::TimelogTxt version 0.003


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

G. Wade Johnson  C<< <wade@cpan.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2011, G. Wade Johnson C<< <wade@cpan.org> >>. All rights reserved.

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
