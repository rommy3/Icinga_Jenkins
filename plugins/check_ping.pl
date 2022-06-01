#!/usr/bin/perl
;#!/usr/local/perl-5.6.1/bin/perl -w

BEGIN{

	push @INC, "/usr/lib/perl5/site_perl/5.8.0/i586-linux-thread-multi";

}

=head1 NAME

check_ping.pl - pings a host and returns statistics data.

=head1 VERSION

Version 1.0

=head1 AUTHOR

(c) 2003 Hannes Schulz <mail@hannes-schulz.de>

=head1 SYNOPSIS

  ./check_ping.pl --host <host> --loss <warn>,<crit> --rta <warn>,<crit> 
                  [--timeout <seconds>] [--packages <packages>]

=head1 DESCRIPTION

This pings a host via the C<Net::Ping> module from CPAN and returns 
RTA and loss.

=cut

use strict;

use Getopt::Long;
use Pod::Usage;
use Net::Ping;

my ($host,$aloss,$arta,$timeout,$pack);
GetOptions(
	"H|host=s",    \$host,
	"l|loss=s",    \$aloss,
	"r|rta=s",     \$arta,
	"t|timeout=i", \$timeout,
	"p|packages=i",\$pack
);

pod2usage("$0: No host given!\n") unless($host);
pod2usage("$0: Parameter syntax error!\n") unless($aloss =~ /^\d+,\d+$/o);
pod2usage("$0: Parameter syntax error!\n") unless($arta =~ /^\d+,\d+$/o);

my ($wloss,$closs) = split /,/,$aloss;
my ($wrta,$crta) = split /,/,$arta;

pod2usage("$0: Warning > Critical!\n") unless($wloss<$closs);
pod2usage("$0: Warning > Critical!\n") unless($wrta<$crta);

$pack     ||= 5;
$timeout  ||= ($pack*3.5);

my $p = Net::Ping->new("tcp",$timeout/$pack);
$p->hires(1);

my ($ret, $duration, $ip, $nok, $dur);
$nok = 0; $dur = 0;
for(1..$pack){
	($ret, $duration, $ip) = $p->ping($host);
	$nok++ if(!$ret);
	$dur += $duration;
	$p->close();
}

my $rta  = 1000 * $dur/$pack;
my $loss = 100  * $nok/$pack;

printf("PING - Packet loss = %i%%, RTA = %.2f ms\n", $loss, $rta);

exit(2) if($rta>$crta or $loss>$closs);  # Nagios: Critical
exit(1) if($rta>$wrta or $loss>$wloss);  # Nagios: Warning
exit(0);                                 # Nagios: OK

