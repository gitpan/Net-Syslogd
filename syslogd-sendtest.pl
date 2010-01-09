#!/usr/bin/perl

use strict;
use IO::Socket;

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
