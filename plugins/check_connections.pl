#!/usr/bin/perl

#
# By Cyril Menigoz
# 
#

# imports
use strict;
use Nagios::Plugin;

# variables
my $shinken;
my $established = 0;
my $listeners = 0;
my $waiting = 0;
my $ss;
my $check_local=" |grep -v 127.0.0.1";

# plugin setup
$shinken = Nagios::Plugin->new(
        plugin          => 'check_connections',
        shortname       => 'CONNECTIONS',
        version         => '1.0',
        usage           => 'Usage: %s -w <warn> -c <crit> [-l <local connection> 1]',
        blurb           => 'This plugin checks the established connections.',
        license         => 'This nagios plugin is free software, and comes with ABSOLUTELY no WARRANTY!'
);

$shinken->add_arg(spec => 'warning|w=s',
                          help => "Warning threshold",
                          required => 1);
$shinken->add_arg(spec => 'critical|c=s',
                          help => "Critical threshold",
                          required => 1);
$shinken->add_arg(spec => 'locale|l=o',
                          help => "Set to 1 to count local connection",
                          required => 0);

# main
$shinken->getopts;
#`echo $shinken->opts->local`;
if ($shinken->opts->locale=~ 1)
{
$check_local="";
}

$ss = `which ss 2> /dev/null`;
chop $ss;
if ( ! -e $ss ) {
        $shinken->nagios_die("Could not find ss binary!");
}


foreach my $entry (split("\n", `$ss -a $check_local`)) {
        if ( $entry =~ m/ESTAB/ ) { $established++; }
        if ( $entry =~ m/SYN-SENT/ )   { $waiting++; }
        if ( $entry =~ m/SYN-WAIT/ )   { $waiting++; }
	if ( $entry =~ m/CLOSE-WAIT/ ) { $waiting++; }
	if ( $entry =~ m/LISTEN/ ) { $listeners++; }
}



my $code = $shinken->check_threshold(
        check => $established,
        warning => $shinken->opts->warning,
        critical => $shinken->opts->critical,
);

my $message = sprintf("There are %d established connections.", $established);

# output
$shinken->add_perfdata(
        label => "established",
        value => $established,
);
$shinken->add_perfdata(
        label => "waiting",
        value => $waiting,
);
$shinken->add_perfdata(
        label => "listeners",
        value => $listeners,
);
$shinken->nagios_exit($code, $message);

