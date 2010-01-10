#!/usr/bin/perl

use strict;
use Test::Simple tests => 3;

use Net::Syslogd;
ok(1, "Loading Module"); # If we made it this far, we're ok.

#########################

sub start_server {
    my $syslogd = Net::Syslogd->new() or return Net::Syslogd->error;
    return 1
};
ok(start_server() == 1, "Starting Server");

sub receive_message {
    my $FAILED = 0;
    my $syslogd = Net::Syslogd->new() or return Net::Syslogd->error;

    my $pid = fork();

    if (!defined($pid)) {
        print "fork() Error!\n";
        exit
    } elsif ($pid == 0) {
        #child
        sleep 2;
        use IO::Socket;
        my $sock=new IO::Socket::INET(PeerAddr => 'localhost',
                                      PeerPort => 514,
                                      Proto    => 'udp') or die "Syslog send test could not start: $!\n";
        print $sock "<174>Dec 11 12:31:15 10.10.10.1 AGENT[$pid]: Strict RFC 3164 format";
        print $sock "<182>AGENT[$pid]: Net::Syslog format";
        print $sock "<190>62: *Dec  4 12:31:15.087: %SYS-5-CONFIG_I: Cisco format";
        $sock->close();
        exit
    } else {
        # parent
        for (1..3) {
            my $message = $syslogd->get_message();
            if (!(defined($message->process_message()))) {
                return Net::Syslogd->error
            } else {
                print "  -- $_ --\n";
                print "  peeraddr = "; if (defined($message->peeraddr) && ($message->peeraddr eq "127.0.0.1"))                                                    { printf "%s\n", $message->peeraddr } else { printf "  !ERROR! - %s\n", $message->peeraddr; $FAILED++ } 
                print "  peerport = "; if (defined($message->peerport) && ($message->peerport =~ /^\d{1,5}$/))                                                    { printf "%s\n", $message->peerport } else { printf "  !ERROR! - %s\n", $message->peerport; $FAILED++ } 
                print "  facility = "; if (defined($message->facility) && ($message->facility =~ /^local[567]$/))                                                 { printf "%s\n", $message->facility } else { printf "  !ERROR! - %s\n", $message->facility; $FAILED++ } 
                print "  severity = "; if (defined($message->severity) && ($message->severity eq "Informational"))                                                { printf "%s\n", $message->severity } else { printf "  !ERROR! - %s\n", $message->severity; $FAILED++ } 
                print "  time     = "; if (defined($message->time)     && (($message->time eq "0") || ($message->time =~ /^Dec\s+[14]{1,2}\s12:31:15[\.087]*$/))) { printf "%s\n", $message->time     } else { printf "  !ERROR! - %s\n", $message->time; $FAILED++ } 
                print "  hostname = "; if (defined($message->hostname) && (($message->hostname eq "0") || ($message->hostname eq "10.10.10.1")))                  { printf "%s\n", $message->hostname } else { printf "  !ERROR! - %s\n", $message->hostname; $FAILED++ } 
                print "  message  = "; if (defined($message->message))                                                                                            { printf "%s\n", $message->message  } else { $FAILED++ } 
            }
        }
    }
    return $FAILED
}
ok(receive_message() == 0, "Received Message");
