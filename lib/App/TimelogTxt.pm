package App::TimelogTxt;

use warnings;
use strict;
use 5.010;

use Carp;
use POSIX qw(strftime);
use Time::Local;
use Getopt::Long qw(:config posix_default);
use Config::Tiny;

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
        synopsis => 'drop [all]',
        help => 'Drop top item from event stack or all if argument supplied.',
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
    return $day if $day =~ m!^\d{4}[-/]\d{1,2}[-/]\d{1,2}$!;
    my $now = time;
    my $delta = 0;
    if( $day eq 'yesterday' ) {
        $delta = 1;
    }
    else {
        my $wday = (localtime $now)[6];
        my $index = 0;
        foreach my $try (qw/sunday monday tuesday wednesday thursday friday saturday/) {
            last if $try eq $day;
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
    my ($day) = @_;

    my $summary = extract_day_tasks( $day );

    print_day_detail( $summary, \*STDOUT );
    return;
}

sub daily_summary {
    my ($day) = @_;

    my $summary = extract_day_tasks( $day );

    print_day_summary( $summary, \*STDOUT );
    return;
}

sub extract_day_tasks {
    my ($day) = @_;
    $day ||= 'today';

    my $stamp = day_stamp( $day );
    my (%tasks, $last, $last_epoch, $last_proj, %proj_dur);
    my ($start, $end, $task);

    open( my $fh, '<', $config{'logfile'} ) or die "Unable to open time log file: $!\n";
    while(<$fh>)
    {
        chop;
        next if -1 == index $_, $stamp;

        next unless my @fields = m{^(\d+)[-/](\d+)[-/](\d+)\s(\d+):(\d+):(\d+)\s+(.*)$};
        $fields[0] -= 1900;
        $fields[1] -= 1;
        $task = pop @fields;
        my ($proj) = $task =~ /\+(\S+)/;
        my $epoch = timelocal( reverse @fields );
        $start ||= $epoch;
        $end = $epoch;
        $tasks{$task} ||= { start=>$epoch, proj => $proj, dur=>0 } unless $task eq 'stop';

        $tasks{$last}->{dur} += $epoch - $last_epoch if $last_epoch;
        $proj_dur{$last_proj} += $epoch - $last_epoch if $last_proj;
        $last = $task;
        $last_epoch = $epoch;
        $last_proj = $proj;
    }

    return unless $end;

    if ( $day eq 'today' and $task ne 'stop' ) {
        my $epoch = time;
        $tasks{$last}->{dur} += $epoch - $last_epoch;
        $proj_dur{$last_proj} += $epoch - $last_epoch;
        $end = $epoch
    }

    return { stamp => $stamp, start => $start, end => $end, dur => $end-$start, tasks => \%tasks, proj_dur => \%proj_dur };
}

sub print_day_detail {
    my ($summary, $fh) = @_;
    return unless ref $summary;
    $fh ||= \*STDOUT;

    my ($tasks, $proj_dur) = @$summary{ qw/tasks proj_dur/ };
    my $last_proj = '';

    print {$fh} "\n$summary->{stamp}\n";
    print {$fh} " $config{'client'} ", format_dur( $summary->{dur} ), "\n";
    foreach my $t ( sort { ($tasks->{$a}->{proj} cmp $tasks->{$b}->{proj}) || ($tasks->{$b}->{start} <=> $tasks->{$a}->{start}) }  keys %{$tasks} )
    {
        if( $tasks->{$t}->{proj} ne $last_proj )
        {
            printf {$fh} '  %-13s%s',  $tasks->{$t}->{proj}, format_dur( $proj_dur->{$tasks->{$t}->{proj}} ). "\n";
            $last_proj = $tasks->{$t}->{proj};
        }
        my $task = $t;
        $task =~ s/\+\S+\s//;
        if ( $task =~ s/\@(\S+)\s*// )
        {
            if ( $task ) {
                printf {$fh} "    %-20s%s (%s)\n", $1, format_dur( $tasks->{$t}->{dur} ), $task;
            }
            else {
                printf {$fh} "    %-20s%s\n", $1, format_dur( $tasks->{$t}->{dur} );
            }
        }
        else {
            printf {$fh} "    %-20s%s\n", $task, format_dur( $tasks->{$t}->{dur} );
        }
    }
    return;
}

sub print_day_summary {
    my ($summary, $fh) = @_;
    return unless ref $summary;
    $fh ||= \*STDOUT;

    my $proj_dur = $summary->{proj_dur};

    print {$fh} "$summary->{stamp}\n";
    print {$fh} " $config{'client'} ", format_dur( $summary->{dur} ), "\n";
    foreach my $p ( sort keys %{$proj_dur} )
    {
        printf {$fh} '  %-13s%s',  $p, format_dur( $proj_dur->{$p} ). "\n";
    }
    return;
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
    if( lc $arg eq 'all' )
    {
        unlink $config{'stackfile'};
    }
    else
    {
        _pop_stack();
    }
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

sub format_dur
{
    my ($dur) = @_;
    $dur += 30; # round, don't truncate.
    sprintf '%2d:%02d', int($dur/3600), int(($dur%3600)/60);
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
