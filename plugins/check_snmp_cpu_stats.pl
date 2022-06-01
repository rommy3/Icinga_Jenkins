#!/usr/bin/perl -w
#
use strict;
use Net::SNMP;
use Getopt::Long;
use lib "/usr/local/libexec";
use utils qw(%ERRORS $TIMEOUT);

### Global and Plugin VARS ###

my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
my $Author="Kilvador";
my $Version='0.1';

my $final_status 	= 0;
my $output			= undef;
my $idle_output		= undef;
my $status			= "OK";
my $perfdata		= undef;
my %hosts_results;

### Constants ###


my $user_cpu_time_percent_oid	= ".1.3.6.1.4.1.2021.11.9.0";
my $system_cpu_time_percent_oid = ".1.3.6.1.4.1.2021.11.10.0";
my $idle_cpu_time_percent_oid 	= ".1.3.6.1.4.1.2021.11.11.0";
my $raw_user_cpu_time_oid 		= ".1.3.6.1.4.1.2021.11.50.0";
my $raw_nice_cpu_time_oid 		= ".1.3.6.1.4.1.2021.11.51.0";
my $raw_system_cpu_time_oid 	= ".1.3.6.1.4.1.2021.11.52.0";
my $raw_idle_cpu_time_oid 		= ".1.3.6.1.4.1.2021.11.53.0";
my $raw_wait_cpu_time_oid 		= ".1.3.6.1.4.1.2021.11.54.0";
my $raw_kernel_cpu_time_oid 	= ".1.3.6.1.4.1.2021.11.55.0";
my $raw_interrupt_cpu_time_oid 	= ".1.3.6.1.4.1.2021.11.56.0";

### Options VARS ###

my $o_host		= undef; 				# Hostname
my $o_community	= undef; 				# Community
my $o_port		= 161; 					# port
my $o_version	= undef;				# print version
my $o_help		= undef;				# print help
my $o_verb		= undef;				# Verbose output
my $o_timeout	= 5;					# Default 5s Timeout
my $o_login		= undef;				# snmp v3 login
my $o_passwd	= undef;				# snmp v3 passwd
my $o_warning	= undef;				# CPU Idle warning threshold in percents
my $o_critical	= undef;				# CPU Idle critical threshold in percents

### Subroutines... ###


sub p_version { print "$0 version : $Version\n"; }
sub p_help {
	p_version();
	print "\nThis plugin monitors CPU Idle of UNIX/LINUX OS and gets a lot of additional Info from SNMPD.
Plugin checks are made via SNMP v2c/3 and returns CPU Idle percent in Output and Perfdata and other stats in Performance data.\n
REQUIRE include .1.3.6.1.4.1.2021 in snmpd.conf\n
STATS, that are getting by this plugin:
	user_cpu_time_percent		= .1.3.6.1.4.1.2021.11.9.0
	system_cpu_time_percent 	= .1.3.6.1.4.1.2021.11.10.0
	idle_cpu_time_percent		= .1.3.6.1.4.1.2021.11.11.0
	raw_user_cpu_time		= .1.3.6.1.4.1.2021.11.50.0
	raw_nice_cpu_time		= .1.3.6.1.4.1.2021.11.51.0
	raw_system_cpu_time		= .1.3.6.1.4.1.2021.11.52.0
	raw_idle_cpu_time		= .1.3.6.1.4.1.2021.11.53.0
	raw_wait_cpu_time		= .1.3.6.1.4.1.2021.11.54.0
	raw_kernel_cpu_time		= .1.3.6.1.4.1.2021.11.55.0
	raw_interrupt_cpu_time_oid	= .1.3.6.1.4.1.2021.11.56.0\n";
	print_usage();
	print "\nOptions:\n
 -h, --help
    Print detailed help screen
 -V, --version
    Print version information
 -H, --hostname=ADDRESS
    Host name, IP Address
 -p, --port=INTEGER
    Port number (default: 161)
 -C, --community=STRING
    Mandatory community string for SNMP communication (default is 'public')
 -l, --login=SNMPv3 Login
    SNMPv3 login
 -x, --privpasswd=PASSWORD
    SNMPv3 privacy password
 -w, --warning
	CPU Idle warning threshold in percents format is: number or number:number
 -c, --critical
	CPU Idle crtical threshold in percents format is: number or number:number
 -V, --version
    Print only version
 -v, --verbose
    Show details for command-line debugging (Nagios may truncate output)
\n";
}

sub print_usage {
	print "Usage:\n$0 -H <host_name>\n-C <snmp_community> -w warning_theshold -c critical_thershold (-l V3_login -x V3_passwd) [-p <port,161 by default>]\n[-v <verbose>] [-V <version>]\n";
}

sub verb { my $t=shift; print $t,"\n" if defined($o_verb) ; }

sub check_options {
	Getopt::Long::Configure ("bundling");
	GetOptions(
		'v'		=> \$o_verb,		'verbose'		=> \$o_verb,
		'H:s'   => \$o_host,		'hostname:s'	=> \$o_host,
		'p:i'   => \$o_port,		'port:i'		=> \$o_port,
		'C:s'   => \$o_community,	'community:s'	=> \$o_community,
		'l:s'   => \$o_login,		'login:s'       => \$o_login,
		'x:s'   => \$o_passwd,		'passwd:s'      => \$o_passwd,
		'w:s'   => \$o_warning,		'warning:s'		=> \$o_warning,
		'c:s'   => \$o_critical,	'critical:s'	=> \$o_critical,
		'V'		=> \$o_version,		'version'		=> \$o_version,
		'h'		=> \$o_help,		'help'			=> \$o_help
	);

	if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"}; }
	if (defined($o_help)) { p_help(); exit $ERRORS{"UNKNOWN"}; }
	if (!defined($o_host)) { print "No HOSTNAME given!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }
	if (!defined($o_community) && (!defined($o_login) || !defined($o_passwd)) ) { print "Put snmp Community and/or Login info!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }
	if (!defined($o_warning) && !defined($o_critical)) { print "No CPU_Idle WARNING/CRITICAL thresholds given!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }
	if ($o_warning !~ /.*?:.*?/ && $o_critical !~ /.*?:.*?/) {
		if ($o_warning < $o_critical) { print "CPU_Idle WARNING must be greater, than CRITICAL threshold!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }
	}
	elsif ($o_warning =~ /.*?:.*?/ && $o_critical =~ /.*?:.*?/) {
		$o_warning =~ /(\d+):(\d+)/;
		my $max_warn = $1;
		my $min_warn = $2;
		$o_critical =~ /(\d+):(\d+)/;
		my $max_crit = $1;
		my $min_crit = $2;
		if ($max_warn < $min_warn) { print "CPU_Idle WARNING max must be greater, than WARNING min!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }
		if ($max_crit < $min_crit) { print "CPU_Idle CRITICAL max must be greater, than CRITICAL min!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }
		if ($min_warn < $max_crit) { print "CPU_Idle WARNING min must be greater, than CRITICAL max!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }
	}
}

sub check_oid {
	my $host=shift;
	my $o_oid=shift;
	my ($session,$error);
	if (defined($o_login) && defined($o_passwd)) {
		verb("SNMPv3 login");
		verb("VARS: $host | $o_community | $o_port | $o_timeout | $o_login | $o_passwd");
		($session, $error) = Net::SNMP->session(
			-hostname	=> $host,
			-version	=> '3',
			-username	=> $o_login,
			-authpassword	=> $o_passwd,
			-authprotocol	=> 'md5',
			-privpassword	=> $o_passwd,
			-timeout	=> $o_timeout
		);
	} else {
		verb("SNMPv2c login");
		verb("VARS: $host | $o_community | $o_port | $o_timeout");
		($session, $error) = Net::SNMP->session(
			-hostname	=> $host,
			-community	=> $o_community,
			-version	=> '2c',
			-port		=> $o_port,
			-timeout	=> $o_timeout
		);
	}
	if (!defined($session)) {
		$error="SNMPERROR: ".$error;
		return($error);
	}
	my $resultat=undef;
	verb("Checking $o_oid");
	$resultat = $session->get_request(-varbindlist => [$o_oid]);
	if (!defined($resultat)) {
		$error=$session->error;
		$error="SNMPERROR: ".$error;
		return($error);
	}
	else {
		foreach my $key (sort keys %$resultat) { return($$resultat{$key}); }
	}
	$session->close;
}

### MAIN ###

check_options();

$idle_output = check_oid($o_host,$idle_cpu_time_percent_oid);

### Analyse WARN and CRIT for CPU Idle - get STATUS ###

verb ("WARN: $o_warning, CRIT: $o_critical");

if ($idle_output =~ /noSuchObject/i) { $status = "UNKNOWN"; $final_status = 3; }
if ($o_warning !~ /\d+:\d+/ && $o_critical !~ /\d+:\d+/) {
	if ($idle_output <= $o_warning && $idle_output > $o_critical) { $status = "WARNING"; $final_status = 1; }
	if ($idle_output <= $o_critical) { $status = "CRITICAL"; $final_status = 2; }
}
else {
	$o_warning =~ /(\d+):(\d+)/;
	my $max_warn = $1;
	my $min_warn = $2;
	$o_critical =~ /(\d+):(\d+)/;
	my $max_crit = $1;
	my $min_crit = $2;
	if ($idle_output <= $max_warn && $idle_output >= $min_warn) { $status = "WARNING"; $final_status = 1; }
	if ($idle_output <= $max_crit && $idle_output >= $min_crit) { $status = "CRITICAL"; $final_status = 2; }
}

$output = "SNMP $status - OS: CPU_Idle $idle_output | 'OS: CPU_Idle'=$idle_output;$o_warning;$o_critical;0;0;";
verb("idle_output: $output");

### Make checks for performance data


my $temp_res = check_oid($o_host,$user_cpu_time_percent_oid);
$perfdata = "user_cpu_time_percent=".$temp_res." ";
$temp_res = check_oid($o_host,$system_cpu_time_percent_oid);
$perfdata .= "system_cpu_time_percent=".$temp_res." ";
$temp_res = check_oid($o_host,$raw_user_cpu_time_oid);
$perfdata .= "raw_user_cpu_time=".$temp_res." ";
$temp_res = check_oid($o_host,$raw_nice_cpu_time_oid);
if ($temp_res !~ /noSuchObject/i) { $perfdata .= "raw_nice_cpu_time=".$temp_res." "; }
$temp_res = check_oid($o_host,$raw_system_cpu_time_oid);
$perfdata .= "raw_system_cpu_time=".$temp_res." ";
$temp_res = check_oid($o_host,$raw_idle_cpu_time_oid);
$perfdata .= "raw_idle_cpu_time=".$temp_res." ";
$temp_res = check_oid($o_host,$raw_wait_cpu_time_oid);
$perfdata .= "raw_wait_cpu_time=".$temp_res." ";
$temp_res = check_oid($o_host,$raw_kernel_cpu_time_oid);
$perfdata .= "raw_kernel_cpu_time=".$temp_res;
$temp_res = check_oid($o_host,$raw_interrupt_cpu_time_oid);
if ($temp_res !~ /noSuchObject/i) { $perfdata .= " raw_interrupt_cpu_time=".$temp_res; }

### VARS for Output ### 

verb("Final_status: $final_status\nFINAL OUTPUT: $output $perfdata");

print "$output $perfdata";

if ($final_status==2) { exit $ERRORS{"CRITICAL"};}
if ($final_status==1) { exit $ERRORS{"WARNING"};}
if ($final_status==3) { exit $ERRORS{"UNKNOWN"};}
exit $ERRORS{"OK"};

#EOF
