#!/usr/bin/perl

use strict;
use Net::Syslogd;
use Getopt::Long qw(:config no_ignore_case); #bundling
use Pod::Usage;

my %opt;
my ($opt_help, $opt_man);

GetOptions(
  'directory=s' => \$opt{'dir'},
  'interface:i' => \$opt{'interface'},
  'write+'      => \$opt{'write'},
  'help!'       => \$opt_help,
  'man!'        => \$opt_man
) or pod2usage(-verbose => 0);

pod2usage(-verbose => 1) if defined $opt_help;
pod2usage(-verbose => 2) if defined $opt_man;

# -d is a directory, if it exists, assign it
if (defined($opt{'dir'})) {

    # replace \ with / for compatibility with UNIX/Windows
    $opt{'dir'} =~ s/\\/\//g;

    # remove trailing / so we're sure it does NOT exist and we CAN put it in later
    $opt{'dir'} =~ s/\/$//;

    if (!(-e $opt{'dir'})) {
        print "$0: directory does not exist - $opt{'dir'}";
        exit 1
    }
    $opt{'write'} = 1 if (!$opt{'write'})
}

if (defined($opt{'interface'})) {
    if (!(($opt{'interface'} > 0) && ($opt{'interface'} < 65536))) {
        print "$0: port not valid - $opt{'interface'}"
    }
} else {
    $opt{'interface'} = '514'
}

my $syslogd = Net::Syslogd->new(
                                'LocalPort' => $opt{'interface'}
                               );

if (!$syslogd) {
    printf "$0: Error creating Syslog listener: %s", Net::Syslogd->error;
    exit 1
}

while (1) {
    my $message;
    if (!($message = $syslogd->get_message())) { next }

    if (!(defined($message->process_message()))) {
        printf "$0: %s\n", Net::Syslogd->error
    } else {
        my $p = sprintf "%s\t%i\t%s\t%s\t%s\t%s\t%s\n", 
                         $message->peeraddr, 
                         $message->peerport, 
                         $message->facility, 
                         $message->severity, 
                         $message->time, 
                         $message->hostname, 
                         $message->message;
        print $p;

        if ($opt{'write'}) {
            my $outfile;
            if (defined($opt{'dir'})) { $outfile = $opt{'dir'} . "/" }

            if    ($opt{'write'} == 1) { $outfile .= "syslogd.log"               }
            elsif ($opt{'write'} == 2) { $outfile .= $message->facility . ".log" }
            else                       { $outfile .= $message->peeraddr . ".log" }

            if (open(OUT, ">>$outfile")) {
                print OUT $p;
                close(OUT)
            } else {
                print STDERR "$0: cannot open outfile - $outfile\n"
            }
        }
    }
}

=head1 NAME

SYSLOGD-SIMPLE - Simple Syslog Server

=head1 SYNOPSIS

 syslod-simple [options]

=head1 DESCRIPTION

Listens for Syslog messages and logs to console and 
optional file.  Tries to decode according to RFC 3164 
message format.  Syslog columns are:

  Source IP Address
  Source UDP port
  Facility
  Severity
  Timestamp (or 0 if not matched)
  Hostname  (or 0 if not matched)
  Message

=head1 OPTIONS

 -d <dir>         Output file directory.
 --directory      DEFAULT:  (or not specified) [Current].

 -i #             UDP Port to listen on.
 --interface      DEFAULT:  (or not specified) 514.

 -w               Log to "syslogd.log".
 -w -w            Log by facility in "<facility>.log".
 -w -w -w         Log by hostname in "<host>.log".

=head1 LICENSE

This software is released under the same terms as Perl itself.
If you don't know what that means visit L<http://perl.com/>.

=head1 AUTHOR

Copyright (C) Michael Vincent 2010

L<http://www.VinsWorld.com>

All rights reserved

=cut
