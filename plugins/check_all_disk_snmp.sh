#!/usr/bin/perl -w

use lib '/usr/lib64/nagios/plugins/';
use utils qw(%ERRORS);
use strict;

# Use this script to snag remote disk information via SNMP
# Written because I need something flexible enough to capture
#   disk info over a variable number of slices/devices

my $VERSION = '2.2';
my $UPDATE = '05.05.2010';
my $D = 0;

my $SNMPDIR = '/usr/bin';

# Turn on/off color HTML output:
my $color = "off";

# Turn on/off help icon/text:
my $help = "off";

# List of partitions to ignore (always!):
my @ignoreme = (
 "/cdrom/",
 "/vobs/",
 "/var/run",
 "/etc/svc/volatile"
);

###############################

my $argument = "";
my ($WP, $WARNING, $CP, $CRITICAL, $INCLUDE, $EXCLUDE, $HOST, $PASS, $TYPE);
my ($helptext, $skipit, $total, $used, $mount, $templine, $matchline);
my $FINALALERT = 0;
my $ALERT = 0;
my ($fulltext, $text, $avail, $displayavail, $displayused, $displaytotal, $percent, $capnum, $perftext);
my (@includethese, @excludethese, $myused, $rounder, $invert);
my (%IDX, @temp, $indexid, $line, %partitionname, %hrStorageSize, %hrStorageUsed, %hrStorageAllocationUnits);

my $counter=0;
## PROCESS COMMAND LINE ARGUMENTS PASSED TO SCRIPT:
foreach $argument (@ARGV) {
   $counter++;
	## ASKING FOR HELP (USAGE):
   usage() if ($argument && $argument =~ m/^-{1,2}h/);
	## ASKING FOR ADDITIONAL HELP (REGEX):
   extendedusage() if ($argument && $argument =~ m/^-{1,2}H/);
   if ($argument && $argument =~ m/^-{1,2}d/i) {
	## TURN ON DEBUG:
     $D = $ARGV[$counter];
   }
   if ($argument && $argument =~ m/^-{1,2}v/i) {
	## VERSION INQUIRY:
     print "$0 version $VERSION last updated $UPDATE\n";
     exit $ERRORS{'OK'};
   }
   if ($argument && $argument =~ m/^-{1,2}w/i) {
	## SET WARNING THRESHOLD:
     $WARNING = $ARGV[$counter];
     if ($WARNING =~ m/\%/) {
       $WP = '%';
       $WARNING =~ s/\%//;
       print "WARNING IS A PERCENTAGE ($WARNING)%\n" if ($D > 1);
     }
   }
   if ($argument && $argument =~ m/^-{1,2}c/i) {
	## SET CRITICAL THRESHOLD:
     $CRITICAL = $ARGV[$counter];
     if ($CRITICAL =~ m/\%/) {
       $CP = '%';
       $CRITICAL =~ s/\%//;
       print "CRITICAL IS A PERCENTAGE ($CRITICAL)%\n" if ($D > 1);
     }
   }
   if ($argument && $argument =~ m/^-{1,2}i/i) {
	## PARTITIONS TO INCLUDE
     $INCLUDE = $ARGV[$counter] if ($ARGV[$counter]);
     # undef($INCLUDE) if ($INCLUDE eq "");
   }
   if ($argument && $argument =~ m/^-{1,2}x/i) {
	## PARTITIONS TO EXCLUDE
     $EXCLUDE = $ARGV[$counter] if ($ARGV[$counter]);
     # undef($EXCLUDE) if ($EXCLUDE eq "");
   }
   if ($argument && $argument =~ m/^-{1,2}t/i) {
	## REMOTE HOSTNAME
     $HOST = $ARGV[$counter];
   }
   if ($argument && $argument =~ m/^-{1,2}p/i) {
	## SNMP PASSWORD
     $PASS = $ARGV[$counter];
   }
   if ($argument && $argument =~ m/^-{1,2}e/i) {
	## Storage type additional to the default one
     $TYPE = $ARGV[$counter];
   }
}

	## BAIL OUT IF CERTAIN REQUIRED ARGUMENTS ARE NOT PRESENT:
&usage() if (! defined $HOST || ! defined $PASS || ! defined $CRITICAL || ! defined $WARNING);

my ($yellow, $red, $font);

if ($color ne "off") {
	## USER WANT COLOR HTML OUTPUT
  $yellow = '<FONT COLOR="yellow">';
  $red = '<FONT COLOR="red">';
  $font = '</FONT><BR>';
} else {
	## USER DOES *NOT* WANT COLOR HTML
  $yellow = '';
  $red = '';
  $font = '';
}

my ($helpopen, $helpclose);

if ($help ne "off") {
	## ADD HELP ICON WITH THRESHOLD SETTINGS:
  $helpopen = "<img src='/nagios/images/info.png' height='10' title='Threshold=";
  $helpclose = "'>";
} else {
  $helpopen = "";
  $helpclose = "";
}

#   ALERT CODES:
my %ALERTLABEL = (
 '0','OK',
 '1','WARNING',
 '2','CRITICAL',
 '3','UNKNOWN',
);

# First grab the list of disk partitions:
# @bulkget = `snmpbulkget -Cr200 -v2c -mALL -t 1 -r 5 -c$PASS $HOST HOST-RESOURCES-MIB::hrStorage`;

my @bulkget = `$SNMPDIR/snmpwalk -v1 -t 5 -r 3 -c $PASS $HOST hrStorage`;


	## PARSE THE LIST AND PULL OUT JUST DISK INFO
print "Initial list of disk variables:\n" if ($D > 2);
foreach $line (@bulkget) {
  chomp($line);
  print " - $line\n" if ($D > 2);
  if ($line =~ m/hrStorageType\.(\d+) =.*hrStorageFixedDisk$/ ||($TYPE && $line =~ m/hrStorageType\.(\d+) =.*$TYPE$/) ) {
    $indexid = $1;
    print " - - MATCH, index id $indexid\n" if ($D > 1);
    $IDX{$indexid} = $indexid; 
  }
}

foreach $indexid (keys(%IDX)) {
  print "Identifying index $indexid\n" if ($D > 1);
  @temp = grep(/hrStorageDescr\.$indexid = STRING:/, @bulkget);
  if (@temp) {
    $partitionname{$indexid} = $temp[0];
    print "\tName match: $partitionname{$indexid}\n" if ($D > 2);
    $partitionname{$indexid} = $1 if ($partitionname{$indexid} =~ m/STRING: (.*)$/);
    print "\tName: $partitionname{$indexid}\n" if ($D > 1);

    @temp =  grep(/hrStorageSize\.$indexid = INTEGER:/, @bulkget);
    if (@temp) {
      $hrStorageSize{$indexid} = $temp[0];
      $hrStorageSize{$indexid} = $1 if ($hrStorageSize{$indexid} =~ m/INTEGER: (\d+)$/);
      print "\tSize: $hrStorageSize{$indexid}\n" if ($D > 1);

      @temp = grep(/hrStorageUsed\.$indexid = INTEGER:/, @bulkget);
      if (@temp) {
        $hrStorageUsed{$indexid} = $temp[0];
        $hrStorageUsed{$indexid} = $1 if ($hrStorageUsed{$indexid} =~ m/INTEGER: (\d+)$/);
        print "\tUsed: $hrStorageUsed{$indexid}\n" if ($D > 1);

        @temp = grep(/hrStorageAllocationUnits\.$indexid = INTEGER:/, @bulkget);
        if (@temp) {
          $hrStorageAllocationUnits{$indexid} = $temp[0];
          $hrStorageAllocationUnits{$indexid} = $1 if ($hrStorageAllocationUnits{$indexid} =~ m/INTEGER: (\d+) Bytes$/);
          print "\tAllocationUnits: $hrStorageAllocationUnits{$indexid}\n" if ($D > 1);

        } else {
          print "Error: Failed to read StorageAllocationUnits for partition '$partitionname{$indexid}' (index: $indexid)\n";
          exit $ERRORS{'UNKNOWN'};
        }
      } else {
        print "Error: Failed to read StorageUsed for partition '$partitionname{$indexid}' (index: $indexid)\n";
        exit $ERRORS{'UNKNOWN'};
      }
    } else {
      print "Error: Failed to read StorageSize for partition '$partitionname{$indexid}' (index: $indexid)\n";
      exit $ERRORS{'UNKNOWN'};
    }
  } else { 
    print "Error: Failed to identify mount point for index id $indexid\n";
    exit $ERRORS{'UNKNOWN'};
  }
}


if ($EXCLUDE) {
  @excludethese = split(',', $EXCLUDE);
}

if ($INCLUDE) {
  @includethese = split(',', $INCLUDE);
}

foreach $indexid (keys(%IDX)) {
  $helptext = "";
  $skipit = 0;
  print "Evaluating index $indexid\n" if ($D > 1);
  $total = $hrStorageSize{$indexid} * $hrStorageAllocationUnits{$indexid};
  $used = $hrStorageUsed{$indexid} * $hrStorageAllocationUnits{$indexid};
  $mount = $partitionname{$indexid};
  print "\t$mount: $total KBytes total and $used KBytes used ($indexid)\n" if ($D > 1);
  next if ($total < 1);	# Avoid div by zero--partitions 0 bytes in size (TOTAL, not used or avail):

    # PARSE OUT PARTITIONS TO IGNORE:
  if (@excludethese) {
    foreach $templine (@excludethese) {
      if ($templine =~ m/\/$/) {
	# TRAILING SLASH -- MATCHES '/partition_name/*'  (wildcard match)
	$matchline = $templine;
	$matchline =~ s/\/$//g;
        if ($mount =~ m/$matchline/) {
          $skipit = 1;
 	}
      } else {
	# NO TRAILING SLASH -- STRICTLY MATCHES '/partition_name'  
        $skipit = 1 if ($templine eq $mount);
      }
    }
  }
    # PARSE OUT PARTITIONS TO INCLUDE:
  if (@includethese) {
    print "Entering include routine\n" if ($D > 2);
    foreach $templine (@includethese) {
      print "  - Checking for '$templine'\n" if ($D > 2);
      if ($templine =~ m/\/$/) {
        print "  - Contains an ending slash\n" if ($D > 2);
	# TRAILING SLASH -- MATCHES '/partition_name/*'  (wildcard match)
	$matchline = $templine;
	$matchline =~ s/\/$//g;
        if ($mount =~ m/$matchline/) {
          $skipit = 0;
	  print "  - $mount matches $matchline, skipit [$skipit]\n" if ($D > 2);
  	} else {
	  print "  - $mount does not match $matchline, skipit [$skipit]\n" if ($D > 2);
  	}
      } else {
	# NO TRAILING SLASH -- STRICTLY MATCHES '/partition_name'  
        print "  - Does not contain ending slash\n" if ($D > 2);
        $skipit = 0 if ($templine eq $mount);
      }
    }
  }
	# ALWAYS IGNORE (DEFINED AT TOP OF SCRIPT):
  foreach $templine (@ignoreme) {
    if ($templine =~ m/\/$/) {
	# TRAILING SLASH -- MATCHES '/partition_name/*'  (wildcard match)
      $skipit = 1 if ($mount =~ m/^$templine/);
    } else {
	# NO TRAILING SLASH -- STRICTLY MATCHES '/partition_name'  
      $skipit = 1 if ($templine eq $mount);
    }
  }
  next if ($skipit > 0);	

  $avail = $total - $used;
  # CONVERT AVAIL (free) SPACE TO MB (FROM KB)
  $avail = int($avail/1048576);
  if ($avail > 1024) {
    # CONVERT TO GB OUTPUT FOR CLARITY
    $displayavail = $avail / 1024;
    $displayavail = sprintf("%0.1f", $displayavail);
    $displayavail = "${displayavail}gb";
  } else {
    # LESS THAN A GB TO REPORT, KEEP AS MB
    $displayavail = "${avail}mb";
  }
  # SET % USED
  $myused = $used / $total; 
	# KEEP ONLY FIRST 3 DIGITS AFTER DECIMAL


  # ------------> modification done to display used and free space in units ---> starts here
  $used = int($used/1048576);
  if ($used > 1024) {
    # CONVERT TO GB OUTPUT FOR CLARITY
    $displayused = $used / 1024;
    $displayused = sprintf("%0.1f", $displayused);
    $displayused = "${displayused}gb";
  } else {
    # LESS THAN A GB TO REPORT, KEEP AS MB
    $displayused = "${used}mb";
  }

  $total = int($total/1048576);
  if ($total > 1024) {
    # CONVERT TO GB OUTPUT FOR CLARITY
    $displaytotal = $total / 1024;
    $displaytotal = sprintf("%0.1f", $displaytotal);
    $displaytotal = "${displaytotal}gb";
  } else {
    # LESS THAN A GB TO REPORT, KEEP AS MB
    $displaytotal = "${total}mb";
  }
  # ------------> ends here
  # ------------> modification checking condition for 100% disk usage
  if ($myused != 1) {
  	$capnum = sprintf("%.3f", $myused);
  	$rounder = substr($capnum,-1,1);
	# DROP LAST DIGIT
  	$capnum = sprintf("%.2f", $capnum);
  	$capnum =~ s/^0\.//;
  	$percent = $capnum;
  	print "raw = $myused, capnum = $capnum, round digit = $rounder, % = $percent \n" if ($D > 2);
  	if ($rounder > 4) {
    		$percent = $percent + 1;
  	}
   } else {
    $percent = $myused * 100;
  } 
  	# SET % FREE
  	$invert = 100 - $percent;
  	$invert = 99 if ($invert > 99);
  	$percent = substr($percent,-1,1) if ($percent =~ m/^0/);
  # $percent = "${percent}%";
  print "\t\t[${percent}% ($displayavail free) on $mount]\n" if ($D > 1);
  $fulltext .= "[${percent}% full,$displaytotal total $displayused used $displayavail free on $mount] ";
  $perftext .= "$mount=${percent}% | ";
  print "\t\tModified output: [$displayavail (${invert}%) free on $mount]\n" if ($D > 0);
  if ($CP && $CP eq '%') {
    #change for ignoring % after thershold value
    #if ($capnum >= $CRITICAL && $ALERT < 2) {
    if ($percent >= $CRITICAL && $ALERT < 2) {
      print "Critical alert: ${percent}% >= ${CRITICAL}%\n" if ($D > 0);
      $ALERT = 2 if ($percent >= ${CRITICAL} && $ALERT < 2);
      $helptext = $helpopen . ${CRITICAL} . "%" . $helpclose if ($help ne "off");
      $text .= "${helptext}${red}[${percent}% full,$displaytotal total $displayused used $displayavail free on ${mount}] $font";
    }
  } else {
    # WARNING LEVEL SET TO MB REMAINING (SPACE FREE)
    if ($avail <= $CRITICAL && $ALERT < 2) {
      print "Critical alert: ${percent}% >= $CRITICAL\n" if ($D > 0);
      $ALERT = 2 if ($avail <= $CRITICAL && $ALERT < 2);
      $helptext = $helpopen . ${CRITICAL} . $helpclose if ($help ne "off");
      $text .= "${helptext}${red}[${percent}% full,$displaytotal total $displayused used $displayavail free on ${mount}] $font";
    }
  }
  if ($WP && $WP eq '%') {
    #change for ignoring % after thershold value
    #if ($capnum >= $WARNING && $ALERT < 1) {
    if ($percent >= $WARNING && $ALERT < 1) {
      print "Warning alert: ${percent}% >= ${WARNING}%\n" if ($D > 0);
      $ALERT = 1;
      $helptext = $helpopen . ${WARNING} . "%" . $helpclose if ($help ne "off");
      $text .= "${helptext}${yellow}[${percent}% full,$displaytotal total $displayused used $displayavail free on ${mount}] $font";
    }
  } else {
    # WARNING LEVEL SET TO MB REMAINING (SPACE FREE)
    if ($avail <= $WARNING && $ALERT < 1) {
      print "Warning alert: ${percent}% >= $WARNING\n" if ($D > 0);
      $ALERT = 1 if ($avail <= $WARNING && $ALERT < 1);
      $helptext = $helpopen . ${WARNING} . $helpclose if ($help ne "off");
      $text .= "${helptext}${yellow}[${percent}% full,$displaytotal total $displayused used $displayavail free on ${mount}] $font";
    }
  }
  $FINALALERT = $ALERT if ($ALERT && $ALERT > $FINALALERT);
  $ALERT = 0; 
}
if ((! $fulltext || $fulltext eq "") && $FINALALERT < 1) {
  $FINALALERT = 3;
  $fulltext = "Cannot retieve disk information";
}

# my %ALERTLABEL = (
 # '0','OK',
 # '1','WARNING',
 # '2','CRITICAL',
 # '3','UNKNOWN',
# );

if ($FINALALERT < 1) {
  print "DISK OK - $fulltext | $perftext\n";
  exit $ERRORS{'OK'};  
} else {
  print "DISK $ALERTLABEL{$FINALALERT}";
  print " - $text | $perftext" if ($text);
  print "\n";
 #%ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
  exit $ERRORS{$ALERTLABEL{$FINALALERT}};
}


#### USAGE SUBROUTINE ####

sub usage {
print <<"EOF";

$0 version $VERSION last updated $UPDATE

 * OVERVIEW *
This utility was written 09/09/2004 as a method for automating
the collection of disk usage information, for the ultimate goal
of pushing the result to Nagios.

 * USAGE *

$0 ARGS

ARGS:
-v              Print version and exit
-h              Print this help message
-H		Extended help (regex tutorial)
-d n            Turn debug on at level n (1-3)
-t		Target (remote hostname)
-p		Password (community string on remote host)
-x              Exclude this filesystem(s) (regex)
-i              Include this filesystem(s) (regex)
-e              Storage type additional to the default one hrStorageFixedDisk(optional)
-w n            Warning level (alert if amount of MB free drops below this level)
   n%           Warning level (alert if % of disk used is greater than this level)
-c n            Critical level
   n%           Critical level

All options can be prefixed with a single or double "-".
All options are case insensitive and only eval the first character
        (e.g. --debug is the same as --d, --D, --Debug, etc)

EOF
exit $ERRORS{'OK'};  
}

sub extendedusage {
print <<"EOF";

Regular expressions valid in the $0 script:

/ 	The trailing slash in a regex is a wildcard (replaces the '*' wildcard)
	Examples:
		'/cdrom'   will match  ^/cdrom
		'/cdrom/'  will match  ^/cdrom*
		'/cdrom//' will match  ^/cdrom/*
		'cdrom/'   will match  *cdrom*

^	Matches the beginning of a string.  This is automatic and therefore this
	character is nearly obsolete.  The only notable exception is to match (only)
	the root partition.  Normally (because it technically ends in a slash), 
	Using this regex:  '/'  Will match every partition!!  To overcome this, 
	use this regex instead:  '^/'

[]	Square brackets will match character ranges.
	Examples:
		'/u0[1-2]/'  will match  /u01* 
			     as well as	 /u02*
		'/[hv]/'     will match  /home*
			     as well as  /var*

Include statements over-write exclude statements. 
Examples:
	If you use these arguments: -x '/u0/' -i '/u02'
  	  You will exlude all /u0* partitions EXCEPT /u02
      	However, if you use these arguments: -x '/u0/' -i '/u0/'
	  You will include all /u0* partitions (-i overrides)

NOTES: 
  - Please enclose all regex strings in single quotes! (')
  - The include option does not indicate "include ONLY these", but rather
    overrides an exclude that is too broad.  To turn the include into
    an "include ONLY these partitions", use this expression:
	-x '^/' -i '/tmp'  (this would only read the /tmp partition)
    Note that the global excludes defined at the top of the $0 script
    will ALWAYS be excluded, and the include statement will NOT override that.

EOF
exit $ERRORS{'OK'};
}

