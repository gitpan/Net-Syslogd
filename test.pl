#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Net-SNMPTrapd.t'

use strict;
use Test::Simple tests => 4;

my $NUM_TESTS = 4;

use Net::Syslogd;
ok(1, "Loading Module"); # If we made it this far, we're ok.

#########################

print <<STOP;

  Net::Syslogd needs to open a network interface and fork 
  a server to perform the full set of tests.  If you're not 
  sure if you have this capability, this will test for it 
  before running.

  To continue without running the tests (if perhaps you 
  know they won't work), simply press 'Enter'.


STOP

print "Continue with tests? ('y' and 'Enter')  : ";
my $answer = <STDIN>;
chomp $answer;

if (lc($answer) ne 'y') {
    for (2..$NUM_TESTS) {
        ok(1, "Skipping test ...")
    }
    exit
}

#########################
# Test 2
sub start_server {
    my $syslogd = Net::Syslogd->new();
    if (defined($syslogd)) {
        return 0
    } else {
        printf "Error: %s\nDo you have a Syslog program listening already?\n  ('netstat -an | grep 514')\n", Net::Syslogd->error;
        return 1
    }
}
if (start_server() == 1) {
    ok(1, "Starting Server - Skipping remaining tests");
    ok(1);
    ok(1);
    exit
} else {
    ok(1, "Starting Server");
}

#########################
# Test 3
sub receive_message {
    my $FAILED = 0;
    my $syslogd = Net::Syslogd->new();
    if (!defined($syslogd)) {
        printf "Error: %s\n", Net::Syslogd->error;
        return 1
    }

    my $pid = fork();

    if (!defined($pid)) {
        print "Error: fork() - $!\n";
        return 1
    } elsif ($pid == 0) {
        #child
        sleep 2;
        use IO::Socket;
        my $sock=new IO::Socket::INET(PeerAddr => 'localhost',
                                      PeerPort => 514,
                                      Proto    => 'udp');
        if (!defined($sock)) {
            printf "Error: Syslog send test could not start: %s\n", $sock->sockopt(SO_ERROR);
            return 1
        }
        print $sock "<174>Dec 11 12:31:15 10.10.10.1 AGENT[$pid]: Strict RFC 3164 format";
        print $sock "<182>AGENT[$pid]: Net::Syslog format";
        print $sock "<190>62: *Dec  4 12:31:15.087: %SYS-5-CONFIG_I: Cisco format";
        $sock->close();
        exit
    } else {
        # parent
        for (1..3) {
            my $message;
            if (!($message = $syslogd->get_message())) {
                printf "Error: %s\n", Net::Syslogd->error;
                return 1
            }
            if (!(defined($message->process_message()))) {
                printf "Error: %s\n", Net::Syslogd->error;
                return 1
            } else {
                print "  -- $_ --\n";
                print "  peeraddr = "; if (defined($message->peeraddr) && ($message->peeraddr eq "127.0.0.1"))                                                    { printf "%s\n", $message->peeraddr } else { printf "  !ERROR! - %s\n", $message->peeraddr; $FAILED++ } 
                print "  peerport = "; if (defined($message->peerport) && ($message->peerport =~ /^\d{1,5}$/))                                                    { printf "%s\n", $message->peerport } else { printf "  !ERROR! - %s\n", $message->peerport; $FAILED++ } 
                print "  facility = "; if (defined($message->facility) && ($message->facility =~ /^local[567]$/))                                                 { printf "%s\n", $message->facility } else { printf "  !ERROR! - %s\n", $message->facility; $FAILED++ } 
                print "  severity = "; if (defined($message->severity) && ($message->severity eq "Informational"))                                                { printf "%s\n", $message->severity } else { printf "  !ERROR! - %s\n", $message->severity; $FAILED++ } 
                print "  time     = "; if (defined($message->time)     && (($message->time eq "0") || ($message->time =~ /^Dec\s+[14]{1,2}\s12:31:15[\.087]*$/))) { printf "%s\n", $message->time     } else { printf "  !ERROR! - %s\n", $message->time;     $FAILED++ } 
                print "  hostname = "; if (defined($message->hostname) && (($message->hostname eq "0") || ($message->hostname eq "10.10.10.1")))                  { printf "%s\n", $message->hostname } else { printf "  !ERROR! - %s\n", $message->hostname; $FAILED++ } 
                print "  message  = "; if (defined($message->message))                                                                                            { printf "%s\n", $message->message  } else { $FAILED++ } 
            }
        }
    }
    return $FAILED
}
ok(receive_message() == 0, "Received Message");

#########################
# Test 4
sub process_as_sub {
    my $FAILED = 0;

    my $message = Net::Syslogd->process_message("<174>Dec 11 12:31:15 10.10.10.1 AGENT[0]: Strict RFC 3164 format");
    print "  facility = "; if (defined($message->facility) && ($message->facility =~ /^local[567]$/))                                                 { printf "%s\n", $message->facility } else { printf "  !ERROR! - %s\n", $message->facility; $FAILED++ } 
    print "  severity = "; if (defined($message->severity) && ($message->severity eq "Informational"))                                                { printf "%s\n", $message->severity } else { printf "  !ERROR! - %s\n", $message->severity; $FAILED++ } 
    print "  time     = "; if (defined($message->time)     && (($message->time eq "0") || ($message->time =~ /^Dec\s+[14]{1,2}\s12:31:15[\.087]*$/))) { printf "%s\n", $message->time     } else { printf "  !ERROR! - %s\n", $message->time;     $FAILED++ } 
    print "  hostname = "; if (defined($message->hostname) && (($message->hostname eq "0") || ($message->hostname eq "10.10.10.1")))                  { printf "%s\n", $message->hostname } else { printf "  !ERROR! - %s\n", $message->hostname; $FAILED++ } 
    print "  message  = "; if (defined($message->message))                                                                                            { printf "%s\n", $message->message  } else { $FAILED++ }
    return $FAILED
}
ok(process_as_sub() == 0, "Process as sub");
