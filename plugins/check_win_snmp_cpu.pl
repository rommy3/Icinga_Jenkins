#!/usr/bin/perl
#
# check_win_snmp_cpu.pl
#
# Author: Brent Ashley <brent@ashleyit.com> 03 Nov 2008
#
# Query Windows Server via SNMP for CPU Load
#
# syntax: check_win_snmp_cpu.pl HOST COMMUNITY WARN CRIT
#
# returns average load % across all CPUs
#

use strict;
use Net::SNMP;

my $host = shift;
my $community = shift;
my $warn = shift;
my $crit = shift;

unless($crit) {
	errorExit("syntax: check_win_snmp_cpu.pl HOST COMMUNITY WARN CRIT");
}

our %ERRORS = (
	OK => 0,
	WARNING => 1,
	CRITICAL => 2,
	UNKNOWN => 3,
	DEPENDENT => 4
);

my $oidCpuTable='.1.3.6.1.2.1.25.3.3.1.2';

# get SNMP session object
my ($snmp, $err) = Net::SNMP->session(
	-hostname => $host,
	-community => $community,
	-port => 161,
	-version => 1 
);
errorExit( $err ) unless (defined($snmp));

# get cpu load table
my $response = $snmp->get_table(
	-baseoid => $oidCpuTable
);
errorExit( "error getting cpu table" ) unless $response;
my %value = %{$response};
$snmp->close();

my $cnt = 0;
my $sum = 0;
foreach my $load ( values %value ){
	$cnt += 1;
	$sum += $load;
};
my $pct = int ($sum / $cnt);

my $err = ($pct > $crit) ? 'CRITICAL' : ($pct > $warn) ? 'WARNING' : 'OK';
print "$err : CPU Load $pct%\n";
exit $ERRORS{$err};

sub errorExit {
	my $msg = shift;
	print "UNKNOWN: $msg\n";
	exit $ERRORS{UNKNOWN};
}


