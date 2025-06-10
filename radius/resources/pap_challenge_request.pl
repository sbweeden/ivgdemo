#!/usr/bin/perl -w

#
# Original version of this file can be found as an attachment to: https://lists.freeradius.org/pipermail/freeradius-users/2012-May/060931.html
#

# Original from: Thomas Glanzmann 16:06 2012-05-21
#
# Modifications for IBM: Peter Calvert 2024-07-13, Shane Weeden 2025-06-10
#
# NOTES:
# - use 'cpan Authen::Radius' command to install if OS does not provide.
#

use strict;
use warnings FATAL => 'all';

use Authen::Radius;
use Data::Dumper;
use IO::Socket::INET;

use constant LOCAL_HOST => '127.0.0.1';
use constant RADIUS_HOST => '127.0.0.1';
use constant RADIUS_SECRET => $ENV{RADIUS_CLIENT_SECRET}; # radius clients have to use the same secret, also used in message authentication codes
use constant RADIUS_TIMEOUT => 70;
use constant CALLING_STATION_ID => LOCAL_HOST;

# autoflush stdout
$| = 1;


sub read_password {
    require Term::ReadKey;

    # Tell the terminal not to show the typed chars
    Term::ReadKey::ReadMode('noecho');

    print "$_[0]";
    my $password = Term::ReadKey::ReadLine(0);

    # Rest the terminal to what it was previously doing
    Term::ReadKey::ReadMode('restore');

    # The one you typed didn't echo!
    print "\n";

    # get rid of that pesky line ending (and works on Windows)
    $password =~ s/\R\z//;

    # say "Password was <$password>"; # check what you are doing :)

    return $password;
}



sub get_local_ip_address {
  my $socket = IO::Socket::INET->new(
      Proto       => 'udp',
      PeerAddr    => '198.41.0.4', # a.root-servers.net - just somewhere to connect to
      PeerPort    => '53', # DNS
  );

  # A side-effect of making a socket connection is that our IP address
  # is available from the 'sockhost' method
  my $local_ip_address = $socket->sockhost;

  return $local_ip_address;
}

my $calling_station_id;
if (CALLING_STATION_ID eq 'detect') {
  $calling_station_id = get_local_ip_address();
} else {
  $calling_station_id = CALLING_STATION_ID;
}


my %response_codes = (
        1   =>   'Access-Request',
        2   =>   'Access-Accept',
        3   =>   'Access-Reject',
        4   =>   'Accounting-Request',
        5   =>   'Accounting-Response',
        11  =>   'Access-Challenge',
        12  =>   'Status-Server (experimental)',
        13  =>   'Status-Client (experimental)',
        255 =>   'Reserved',

);


my $username = $ARGV[0];
my $password = $ARGV[1];

unless (defined($username)) {
  print "Enter username: ";
  $username = <STDIN>;
  chomp($username);
}

unless (defined($password)) {
  $password = read_password('Enter password: ');
}

print "Allocating Authen::Radius\n";
my $r = new Authen::Radius(
	Host=>RADIUS_HOST,
       	Secret=>RADIUS_SECRET,
       	Timeout=>RADIUS_TIMEOUT,
       	LocalAddr=>LOCAL_HOST,
	Rfc3579MessageAuth=>"true",
       	Debug=>"true"
);
print Authen::Radius::strerror();
print "Allocated\n";

Authen::Radius->load_dictionary();

$r->add_attributes (
    { Name => 'User-Name', Value => $username },
    { Name => 'NAS-IP-Address', Value => $calling_station_id },
    { Name => 'Service-Type', Value => 'Authenticate-Only' },
    { Name => 'Proxy-State', Value => $username },
);

if ($password ne "") {
  $r->add_attributes (
      { Name => 'User-Password', Value => $password },
  );
}

$r->set_timeout(time() + RADIUS_TIMEOUT);
print "sending RADIUS request\n";
$r->send_packet(ACCESS_REQUEST)  || die;

my $type = $r->recv_packet() || die($r->get_error());

print "server response type = $response_codes{$type} ($type)\n";

my ($state, $replyMessage, $otp, $echoPrompt);

while($type == ACCESS_CHALLENGE) {
  $state = undef;
  $replyMessage = "enter otp:";
  $echoPrompt = 0;

  for $a ($r->get_attributes()) {
    if ($a->{Name} eq 'State') {
      print $a->{Name} . ' -> ' . $a->{RawValue} . "\n";
      $state = $a->{RawValue};
    } elsif ($a->{Name} eq 'Reply-Message') {
      print $a->{Name} . ' -> ' . $a->{Value} . "\n";
      $replyMessage = $a->{RawValue};
    } elsif ($a->{Name} eq 'Prompt') {
      print $a->{Name} . ' -> ' . $a->{Value} . "\n";
      $echoPrompt = $a->{Value};
    }
    else {
      print $a->{Name} . ' -> ' . $a->{RawValue} . "\n";
    }
  }

  print $replyMessage . ' ';
  if ($echoPrompt) {
    $otp = <STDIN>;
  } else {
    $otp = read_password('');
  }
  chomp($otp);

  $r->clear_attributes();
  $r->add_attributes (
      { Name => 'User-Name', Value => $username },
      { Name => 'State', Value => $state },
      { Name => 'Proxy-State', Value => $username },
  );
  if ($otp ne "") {
    $r->add_attributes (
        { Name => 'User-Password', Value => $otp },
    );
  }

  $r->set_timeout(time() + 60);
  $r->send_packet(ACCESS_REQUEST)  || die;
  $type = $r->recv_packet() || die($r->get_error());
  print "server response type = $response_codes{$type} ($type)\n";
}

for $a ($r->get_attributes()) {
    if ($a->{Value}) {
      print $a->{Name} . ' -> ' . $a->{Value} . "\n";
    }
    else {
      print $a->{Name} . ' -> ' . $a->{RawValue} . "\n";
    }
}

exit 1 unless $type == 2; # Remember type 2 is Access-Accept
