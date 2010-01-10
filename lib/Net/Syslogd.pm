package Net::Syslogd;

########################################################
#
# AUTHOR = Michael Vincent
# www.VinsWorld.com
#
########################################################

require 5.005;

use strict;
use Exporter;

use IO::Socket;

our $VERSION     = '0.01';
our @ISA         = qw(Exporter);
our @EXPORT      = qw();
our %EXPORT_TAGS = (
                    'all' => [qw(@FACILITY @SEVERITY)]
                   );
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

########################################################
# Start Variables
########################################################
use constant SYSLOGD_DEFAULT_PORT => 514;
use constant SYSLOGD_MAX_SIZE     => 65511;

our @FACILITY = qw(kernel user mail system security internal printer news uucp clock security2 FTP NTP audit alert clock2 local0 local1 local2 local3 local4 local5 local6 local7);
our @SEVERITY = qw(Emergency Alert Critical Error Warning Notice Informational Debug);
our $LASTERROR;
########################################################
# End Variables
########################################################

########################################################
# Start Public Module
########################################################

sub new {
    my $self = shift;
    my $class = ref($self) || $self;

    my %cfg = @_;

    my %params = (
        'Proto' => 'udp',
        'LocalPort' => $cfg{'LocalPort'} || SYSLOGD_DEFAULT_PORT,
    );

    if ($cfg{'LocalAddr'}) {
        $params{'LocalAddr'} = $cfg{'LocalAddr'}
    }

    if (my $udpserver = IO::Socket::INET->new(%params)) {
        return bless {
                      'LocalPort'   => SYSLOGD_DEFAULT_PORT,
                      'Timeout'     => 10,
                      %cfg,         # merge user parameters
                      '_UDPSERVER_' => $udpserver
                     }, $class
    } else {
        $LASTERROR = "Error opening socket for listener: $@\n";
        return(undef)
    }
}

sub get_message {

    my $self  = shift;
#    my $class = ref($self) || $self;

    my $message;

    foreach my $key (keys(%{$self})) {
        # everything but '_xxx_'
        $key =~ /^\_.+\_$/ and next;
        $message->{$key} = $self->{$key}
    }

    my $Timeout = $message->{'Timeout'};
    my $udpserver = $self->{'_UDPSERVER_'};

    my $datagram;

    # vars for IO select
    my ($rin, $rout, $ein, $eout) = ('', '', '', '');
    vec($rin, fileno($udpserver), 1) = 1;

    # check if a message is waiting
    if (select($rout=$rin, undef, $eout=$ein, $Timeout)) {
        # read the message
        if ($udpserver->recv($datagram, SYSLOGD_MAX_SIZE)) {

            my ($peerport, $peeraddr) = sockaddr_in($udpserver->peername);
            $message->{'_MESSAGE_'}{'PeerPort'} = $peerport;
            $message->{'_MESSAGE_'}{'PeerAddr'} = inet_ntoa($peeraddr);
            $message->{'_MESSAGE_'}{'datagram'} = $datagram;

            return bless $message #, $class
        } else {
            $! = $udpserver->sockopt(SO_ERROR);
            $LASTERROR = sprintf "Socket RECV error: %s\n", $!;
            return(undef)
        }
    } else {
        $LASTERROR = "Timed out waiting for datagram";
        return(0)
    }
}

sub process_message {

    my $self = shift;
#    my $class = ref($self) || $self;

    # Syslog RFC 3164 correct format:
    # <###>Mmm dd hh:mm:ss hostname tag msg
    # NOTE:  This script parses the tag and msg as a single field called msg
    #
    # Attempt 1:
    # $datagram =~ /<(\d{1,3})>(([JFMASONDjfmasond]\w\w) {1,2}(\d+) (\d{2}:\d{2}:\d{2}) )?((([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})|([a-zA-Z\-]+)) )?(.*)/;
    #
    # Attempt 2: this accounts for the Cisco format (not strict RFC 3164)
    $self->{'_MESSAGE_'}{'datagram'} =~ /<(\d{1,3})>[\d{1,}: \*]*(([JFMASONDjfmasond]\w\w) {1,2}(\d+) (\d{2}:\d{2}:\d{2}[\.\d{1,3}]*))?:*\s*((([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})|([a-zA-Z\-]+)) )?(.*)/;

    $self->{'_MESSAGE_'}{'priority'} = $1;
    $self->{'_MESSAGE_'}{'time'}     = $2 || 0;
    $self->{'_MESSAGE_'}{'hostname'} = $6 || 0;
    $self->{'_MESSAGE_'}{'message'}  = $10;
    $self->{'_MESSAGE_'}{'severity'} = $self->{'_MESSAGE_'}{'priority'} % 8;
    $self->{'_MESSAGE_'}{'facility'} = ($self->{'_MESSAGE_'}{'priority'} - $self->{'_MESSAGE_'}{'severity'}) / 8;

    $self->{'_MESSAGE_'}{'hostname'} =~ s/\s+//;

    return bless $self #, $class
}

sub datagram {
    my $self = shift;
    return $self->{'_MESSAGE_'}{'datagram'}
}

sub peeraddr {
    my $self = shift;
    return $self->{'_MESSAGE_'}{'PeerAddr'}
}

sub peerport {
    my $self = shift;
    return $self->{'_MESSAGE_'}{'PeerPort'}
}

sub priority {
    my $self = shift;
    return $self->{'_MESSAGE_'}{'priority'}
}

sub facility {
    my ($self, $arg) = @_;

    if (defined($arg) && ($arg > 1)) {
        return $self->{'_MESSAGE_'}{'facility'}
    } else {
        return $FACILITY[$self->{'_MESSAGE_'}{'facility'}]
    }
}

sub severity {
    my ($self, $arg) = @_;

    if (defined($arg) && ($arg > 1)) {
        return $self->{'_MESSAGE_'}{'severity'}
    } else {
        return $SEVERITY[$self->{'_MESSAGE_'}{'severity'}]
    }
}

sub time {
    my $self = shift;
    return $self->{'_MESSAGE_'}{'time'}
}

sub hostname {
    my $self = shift;
    return $self->{'_MESSAGE_'}{'hostname'}
}

sub message {
    my $self = shift;
    return $self->{'_MESSAGE_'}{'message'}
}

sub error {
    return($LASTERROR)
}

########################################################
# End Public Module
########################################################

########################################################
# Start Private subs
########################################################

########################################################
# End Private subs
########################################################

1;

__END__

########################################################
# Start POD
########################################################

=head1 NAME

Net::Syslogd - Perl implementation of Syslog Listener

=head1 SYNOPSIS

  use Net::Syslogd;

  my $syslogd = Net::Syslogd->new()
    or die "Error creating Syslogd listener: %s", Net::Syslogd->error;

  while (1) {
      my $message;
      if (!($message = $syslogd->get_message())) { next }

      if (!(defined($message->process_message()))) {
          printf "$0: %s\n", Net::Syslogd->error
      } else {
          printf "%s\t%i\t%s\t%s\t%s\t%s\t%s\n", 
                 $message->peeraddr, 
                 $message->peerport, 
                 $message->facility, 
                 $message->severity, 
                 $message->time, 
                 $message->hostname, 
                 $message->message
      }
  }

=head1 DESCRIPTION

Net::Syslogd is a class implementing a simple Syslog listener in Perl.  
Net::Syslogd will accept messages on the default Syslog port (UDP 514) 
and attempt to decode them according to RFC 3164.

=head1 METHODS

=head2 new() - create a new Net::Syslogd object

  my $syslogd = new Net::Syslogd([OPTIONS]);

or

  my $syslogd = Net::Syslogd->new([OPTIONS]);

Create a new Net::Syslogd object with OPTIONS as optional parameters.
Valid options are:

  Option     Description                            Default
  ------     -----------                            -------
  -LocalAddr Interface to bind to                       any
  -LocalPort Port to bind server to                     514
  -Timeout   Timeout in seconds to wait for request      10

=head2 get_message() - listen for Syslog message

  $syslogd->get_message();

Listen for a Syslog message.  Timeout after default or user specified 
timeout set in C<new> method and return '0'; else, return is defined.

=head2 process_message() - process received Syslog message

  $syslogd->process_message();

Process a received Syslog message by RFC 3164 - or as close as possible. 
RFC 3164 format is as follows:

  <###>Mmm dd hh:mm:ss hostname tag msg

  |___||_____________|
    |         Time
   Priority

B<NOTE:>  This script parses the tag and msg as a single field.

Allows the following methods to be called.

=head3 datagram() - return datagram from Syslog message

  $syslogd->datagram();

Return the raw datagram received from a processed (C<process_message()>) 
Syslog message.

=head3 peeraddr() - return remote address from Syslog message

  $syslogd->peeraddr();

Return peer address value from a received and processed 
(C<process_message()>) Syslog message.  This is the address from the IP 
header on the UDP datagram.

=head3 peerport() - return remote port from Syslog message

  $syslogd->peerport();

Return peer port value from a received and processed 
(C<process_message()>) Syslog message.  This is the port from the IP 
header on the UDP datagram.

=head3 priority() - return priority from Syslog message

  $syslogd->priority();

Return priority value from a received and processed 
(C<process_message()>) Syslog message.  This is the raw priority number 
not decoded into facility and severity.

=head3 facility() - return facility from Syslog message

  $syslogd->facility([1]);

Return facility value from a received and processed 
(C<process_message()>) Syslog message.  This is the text representation 
of the facility.  For the raw number, use the optional boolean argument.

=head3 severity() - return severity from Syslog message

  $syslogd->severity([1]);

Return severity value from a received and processed 
(C<process_message()>) Syslog message.  This is the text representation 
of the severity.  For the raw number, use the optional boolean argument.

=head3 time() - return time from Syslog message

  $syslogd->time();

Return time value from a received and processed 
(C<process_message()>) Syslog message.

=head3 hostname() - return hostname from Syslog message

  $syslogd->hostname();

Return hostname value from a received and processed 
(C<process_message()>) Syslog message.

=head3 message() - return message from Syslog message

  $syslogd->message();

Return message value from a received and processed 
(C<process_message()>) Syslog message.  Note this is the tag B<and> msg 
field from a properly formatted RFC 3164 Syslog message.

=head2 error() - print last error

  printf "Error: %s\n", $Net::Syslogd->error;

Return last error.

=head1 EXPORT

None by default.

=head1 EXAMPLES

=head2 Simple Syslog Server

This example implements a simple Syslog server that listens on the 
default port and prints received messages to the console.

  use Net::Syslogd;

  my $syslogd = Net::Syslogd->new()
    or die "Error creating Syslogd listener: %s", Net::Syslogd->error;

  while (1) {
      my $message;
      if (!($message = $syslogd->get_message())) { next }

      if (!(defined($message->process_message()))) {
          printf "$0: %s\n", Net::Syslogd->error
      } else {
          printf "%s\t%i\t%s\t%s\t%s\t%s\t%s\n", 
                 $message->peeraddr, 
                 $message->peerport, 
                 $message->facility, 
                 $message->severity, 
                 $message->time, 
                 $message->hostname, 
                 $message->message
      }
  }

=head2 Forking Syslog Server

  use Net::Syslogd;

  my $syslogd = Net::Syslogd->new()
    or die "Error creating Syslogd listener: %s", Net::Syslogd->error;

  while (1) {
      my $message;
      if (!($message = $syslogd->get_message())) { next }

      my $pid = fork();

      if (!defined($pid)) {
          print "fork() Error!\n";
          exit
      } elsif ($pid == 0) {
          if (!(defined($message->process_message()))) {
              printf "$0: %s\n", Net::Syslogd->error
          } else {
              printf "%s\t%i\t%s\t%s\t%s\t%s\t%s\n", 
                     $message->peeraddr, 
                     $message->peerport, 
                     $message->facility, 
                     $message->severity, 
                     $message->time, 
                     $message->hostname, 
                     $message->message
          }
          exit
      } else {
          # parent
      }
  }

=head1 LICENSE

This software is released under the same terms as Perl itself.
If you don't know what that means visit L<http://perl.com/>.

=head1 AUTHOR

Copyright (C) Michael Vincent 2010

L<http://www.VinsWorld.com>

All rights reserved

=cut
