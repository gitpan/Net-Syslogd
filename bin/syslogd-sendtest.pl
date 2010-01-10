#!/usr/bin/perl

use strict;
use IO::Socket;
use Getopt::Long qw(:config no_ignore_case); #bundling
use Pod::Usage;

my %opt;
my ($opt_help, $opt_man);

GetOptions(
  'help!'       => \$opt_help,
  'man!'        => \$opt_man
) or pod2usage(-verbose => 0);

pod2usage(-verbose => 1) if defined $opt_help;
pod2usage(-verbose => 2) if defined $opt_man;

my @logs = (
            # Strict RFC 3164
            "<174>Dec 11 12:31:15 192.168.200.1 $0[$$]: Strict RFC 3164 format",

            # Net::Syslog
            "<182>$0[$$]: Net::Syslog format",

            # Cisco
            "<190>62: *Dec  4 12:31:15.087: %SYS-5-CONFIG_I: Cisco format"
           );

for (@logs) {
    my $sock=new IO::Socket::INET(PeerAddr => 'localhost',
                                  PeerPort => 514,
                                  Proto    => 'udp') or die "Socket could not be created : $!\n";

    print $sock $_;
    $sock->close();
}

=head1 NAME

SYSLOGD-SENDTEST - Syslog Message Tests

=head1 SYNOPSIS

 syslod-sendtest

=head1 DESCRIPTION

Sends sample Syslog messages.

=head1 LICENSE

This software is released under the same terms as Perl itself.
If you don't know what that means visit L<http://perl.com/>.

=head1 AUTHOR

Copyright (C) Michael Vincent 2010

L<http://www.VinsWorld.com>

All rights reserved

=cut
