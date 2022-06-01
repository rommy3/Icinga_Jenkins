#!/usr/bin/perl -w

use lib '/usr/lib64/nagios/plugins/';
use utils qw(%ERRORS);
use strict;

# Use this script to snag remote disk information via SNMP
# Written because I need something flexible enough to capture
#   disk info over a variable number of slices/devices

my $VERSION = '2.2';
my $UPDATE = '12.08.2013';
my $D = 0;

my $SNMPDIR = '/usr/bin';

# Turn on/off color HTML output:
my $color = "off";

# Turn on/off help icon/text:
my $help = "off";

# List of partitions to ignore (always!):
my @ignoreme = (
 "/cdrom/",
 "/mnt/",
 "/vobs/",
 "/var/run",
 "/etc/svc/volatile",
 "/run/user/"
);

###############################
my $TMOUT = 30;
my $RETRYCNT = 1;

my $argument = "";
my ($WP, $WARNING, $CP, $CRITICAL, $INCLUDE, $EXCLUDE, $HOST, $PASS, $TYPE);
my ($helptext, $skipit, $total, $used, $mount, $templine, $matchline);
my $FINALALERT = 0;
my $ALERT = 0;
my ($fulltext, $text, $avail, $displayavail, $displayused, $displaytotal, $percent, $capnum, $perftext);
my (@includethese, @excludethese, $myused, $rounder, $invert);
my (%IDX, @temp, $tmp, $indexid, $line, %partitionname, %hrStorageSize, %hrStorageUsed, %hrStorageAvail, %hrStorageAllocationUnits, %diskPercent);

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
   if ($argument && $argument =~ m/^-{1,2}q/i) {
	## SNMP Timeout values
     $TMOUT = $ARGV[$counter];
   }
   if ($argument && $argument =~ m/^-{1,2}z/i) {
	## SNMP Timeout values
     $RETRYCNT = $ARGV[$counter];
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
#@bulkget = `snmpget -Cr200 -v2c -mALL -t 1 -r 5 -c$PASS $HOST .1.3.6.1.4.1.2021.9.1.9.1`;
my @bulkget = `$SNMPDIR/snmpwalk -v2c -t $TMOUT -r $RETRYCNT -c $PASS $HOST hrStorage`;
my @bulkdskentry =`$SNMPDIR/snmpwalk -v2c -t $TMOUT -r $RETRYCNT -c $PASS $HOST dskEntry`;


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

  } else { 
    print "Error: Failed to identify mount point for index id $indexid\n";
    exit $ERRORS{'UNKNOWN'};
  }
}

foreach $indexid (keys(%partitionname)) {
  @temp = grep(/dskPath\.\d+ = STRING: $partitionname{$indexid}$/, @bulkdskentry);
  if (@temp) {
    $IDX{$indexid} = $temp[0];
    $IDX{$indexid} = $1 if ($IDX{$indexid} =~ m/dskPath\.(\d+) =/);

    @temp =  grep(/dskTotal\.$IDX{$indexid} = INTEGER:/, @bulkdskentry);
    if (@temp) {
      $hrStorageSize{$indexid} = $temp[0];
      $hrStorageSize{$indexid} = $1 if ($hrStorageSize{$indexid} =~ m/INTEGER: (\d+)$/);
      if($hrStorageSize{$indexid}>=2147483647){
        @temp = grep(/dskTotalLow\.$IDX{$indexid} = Gauge32:/, @bulkdskentry);
        if(@temp){
          $hrStorageSize{$indexid} = $temp[0];
          $hrStorageSize{$indexid} = $1 if ($hrStorageSize{$indexid} =~ m/Gauge32: (\d+)$/);
          
          @temp = grep(/dskTotalHigh\.$IDX{$indexid} = Gauge32:/, @bulkdskentry);
          if(@temp){
            $tmp = $temp[0];
            $tmp = $1 if ($tmp =~ m/Gauge32: (\d+)$/);
            $hrStorageSize{$indexid} = ($tmp * 4294967296) + $hrStorageSize{$indexid};
          } else{
              print "Error: Failed to read disk usage total high for partition '$partitionname{$indexid}'\n";
              exit $ERRORS{'UNKNOWN'};
          }
        } else{
            print "Error: Failed to read disk usage total low for partition '$partitionname{$indexid}'\n";
            exit $ERRORS{'UNKNOWN'};
        }
      }

      @temp = grep(/dskUsed\.$IDX{$indexid} = INTEGER:/, @bulkdskentry);
      if (@temp) {
        $hrStorageUsed{$indexid} = $temp[0];
        $hrStorageUsed{$indexid} = $1 if ($hrStorageUsed{$indexid} =~ m/INTEGER: (\d+)$/);

        if($hrStorageUsed{$indexid}>=2147483647){
          @temp = grep(/dskUsedLow\.$IDX{$indexid} = Gauge32:/, @bulkdskentry);
          if(@temp){
            $hrStorageUsed{$indexid} = $temp[0];
            $hrStorageUsed{$indexid} = $1 if ($hrStorageUsed{$indexid} =~ m/Gauge32: (\d+)$/);
            
            @temp = grep(/dskUsedHigh\.$IDX{$indexid} = Gauge32:/, @bulkdskentry);
            if(@temp){
              $tmp = $temp[0];
              $tmp = $1 if ($tmp =~ m/Gauge32: (\d+)$/);
              $hrStorageUsed{$indexid} = ($tmp * 4294967296) + $hrStorageUsed{$indexid};
            } else{
                print "Error: Failed to read disk usage used high for partition '$partitionname{$indexid}'\n";
                exit $ERRORS{'UNKNOWN'};
            }
          } else{
              print "Error: Failed to read disk usage used low for partition '$partitionname{$indexid}'\n";
              exit $ERRORS{'UNKNOWN'};
          }
        }

        @temp = grep(/dskAvail\.$IDX{$indexid} = INTEGER:/, @bulkdskentry);
        if(@temp){
          $hrStorageAvail{$indexid} = $temp[0];
          $hrStorageAvail{$indexid} = $1 if ($hrStorageAvail{$indexid} =~ m/INTEGER: (\d+)$/);
          if($hrStorageAvail{$indexid}>=2147483647){
            @temp = grep(/dskAvailLow\.$IDX{$indexid} = Gauge32:/, @bulkdskentry);
            if(@temp){
              $hrStorageAvail{$indexid} = $temp[0];
              $hrStorageAvail{$indexid} = $1 if ($hrStorageAvail{$indexid} =~ m/Gauge32: (\d+)$/);
              
              @temp = grep(/dskAvailHigh\.$IDX{$indexid} = Gauge32:/, @bulkdskentry);
              if(@temp){
                $tmp = $temp[0];
                $tmp = $1 if ($tmp =~ m/Gauge32: (\d+)$/);
                $hrStorageAvail{$indexid} = ($tmp * 4294967296) + $hrStorageAvail{$indexid};
              } else{
                  print "Error: Failed to read disk usage avail high for partition '$partitionname{$indexid}'\n";
                  exit $ERRORS{'UNKNOWN'};
              }
            } else{
                print "Error: Failed to read disk usage avail low for partition '$partitionname{$indexid}'\n";
                exit $ERRORS{'UNKNOWN'};
            }
          }

           @temp = grep(/dskPercent\.$IDX{$indexid} = INTEGER:/, @bulkdskentry);
          if(@temp){
            $diskPercent{$indexid} = $temp[0];
            $diskPercent{$indexid} = $1 if ($diskPercent{$indexid} =~ m/INTEGER: (\d+)$/);
          } else{
            print "Error: Failed to read disk percent for partition '$partitionname{$indexid}'\n";
            exit $ERRORS{'UNKNOWN'};
          }
        } else{
          print "Error: Failed to read disk avail for partition '$partitionname{$indexid}'\n";
          exit $ERRORS{'UNKNOWN'};
        }
      } else{
        print "Error: Failed to read disk used for partition '$partitionname{$indexid}'\n";
        exit $ERRORS{'UNKNOWN'};
      }
    } else{
      print "Error: Failed to read total size for partition $partitionname{$indexid}\n";
      exit $ERRORS{'UNKNOWN'};
    }
  } else { 
      @temp = grep(/hrStorageAllocationUnits\.$indexid = INTEGER:/, @bulkget);
      if (@temp) {
        $hrStorageAllocationUnits{$indexid} = $temp[0];
        $hrStorageAllocationUnits{$indexid} = $1 if ($hrStorageAllocationUnits{$indexid} =~ m/INTEGER: (\d+) Bytes$/);

        @temp =  grep(/hrStorageSize\.$indexid = INTEGER:/, @bulkget);
        if (@temp) {
          $hrStorageSize{$indexid} = $temp[0];
          $hrStorageSize{$indexid} = $1 if ($hrStorageSize{$indexid} =~ m/INTEGER: (\d+)$/);
	  if ($hrStorageSize{$indexid} > 2147483647 || $hrStorageSize{$indexid} <0){
            print "Warning: StorageSize for $partitionname{$indexid} exceeds integer limit. Restart snmpd service to get actual value\n";
            exit $ERRORS{'WARNING'};
	  }
          $hrStorageSize{$indexid} = ($hrStorageSize{$indexid} * $hrStorageAllocationUnits{$indexid})/1024;
  	  next if ($hrStorageSize{$indexid} < 1);	# Avoid div by zero--partitions 0 bytes in size (TOTAL, not used or avail):

          @temp = grep(/hrStorageUsed\.$indexid = INTEGER:/, @bulkget);
          if (@temp) {
            $hrStorageUsed{$indexid} = $temp[0];
            $hrStorageUsed{$indexid} = $1 if ($hrStorageUsed{$indexid} =~ m/INTEGER: (\d+)$/);
	    if ($hrStorageUsed{$indexid} > 2147483647 || $hrStorageUsed{$indexid} <0){
              print "Warning: StorageSize for $partitionname{$indexid} exceeds integer limit. Restart snmpd service to get actual value\n";
              exit $ERRORS{'WARNING'};
	    }
            $hrStorageUsed{$indexid} = ($hrStorageUsed{$indexid} * $hrStorageAllocationUnits{$indexid})/1024;

            $hrStorageAvail{$indexid} = $hrStorageSize{$indexid} - $hrStorageUsed{$indexid};

  	    $myused = $hrStorageUsed{$indexid} / $hrStorageSize{$indexid}; 
  	    $capnum = sprintf("%.3f", $myused);
  	    $rounder = substr($capnum,-1,1);
  	    $capnum = sprintf("%.2f", $capnum);
  	    $capnum =~ s/^0\.//;
  	    $percent = $capnum;
  	    if ($rounder > 4) {
  	      $percent = $percent + 1;
  	    }
	    $diskPercent{$indexid} = $percent;
          } else {
            print "Error: Failed to read StorageUsed for partition '$partitionname{$indexid}' (index: $indexid)\n";
            exit $ERRORS{'UNKNOWN'};
          }
        } else {
          print "Error: Failed to read StorageSize for partition '$partitionname{$indexid}' (index: $indexid)\n";
          exit $ERRORS{'UNKNOWN'};
        }
      } else {
        print "Error: Failed to read StorageAllocationUnits for partition '$partitionname{$indexid}' (index: $indexid)\n";
        exit $ERRORS{'UNKNOWN'};
      }
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
  $total = $hrStorageSize{$indexid};
  $used = $hrStorageUsed{$indexid};
  $avail = $hrStorageAvail{$indexid};
  $mount = $partitionname{$indexid};
  $percent = $diskPercent{$indexid};
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
  foreach $templine (@ignoreme) {
    if ($templine =~ m/\/$/) {
	# TRAILING SLASH -- MATCHES '/partition_name/*'  (wildcard match)
      $skipit = 1 if ($mount =~ m/^$templine/);
    } else {
	# NO TRAILING SLASH -- STRICTLY MATCHES '/partition_name'  
      $skipit = 1 if ($templine eq $mount);
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
  next if ($skipit > 0);	

  # CONVERT AVAIL (free) SPACE TO MB (FROM KB)
  $avail = int($avail/1024);
  if ($avail > 1048576){
    # CONVERT TO TB OUTPUT FOR CLARITY
    $displayavail = $avail / 1048576;
    $displayavail = sprintf("%0.1f", $displayavail);
    $displayavail = "${displayavail}tb";
  } elsif ($avail > 1024) {
    # CONVERT TO GB OUTPUT FOR CLARITY
    $displayavail = $avail / 1024;
    $displayavail = sprintf("%0.1f", $displayavail);
    $displayavail = "${displayavail}gb";
  } else {
    # LESS THAN A GB TO REPORT, KEEP AS MB
    $displayavail = "${avail}mb";
  }
	# KEEP ONLY FIRST 3 DIGITS AFTER DECIMAL


  # ------------> modification done to display used and free space in units ---> starts here
  $used = int($used/1024);
  if ($used > 1048576){
    # CONVERT TO TB OUTPUT FOR CLARITY
    $displayused = $used / 1048576;
    $displayused = sprintf("%0.1f", $displayused);
    $displayused = "${displayused}tb";
  } elsif ($used > 1024) {
    # CONVERT TO GB OUTPUT FOR CLARITY
    $displayused = $used / 1024;
    $displayused = sprintf("%0.1f", $displayused);
    $displayused = "${displayused}gb";
  } else {
    # LESS THAN A GB TO REPORT, KEEP AS MB
    $displayused = "${used}mb";
  }

  $total = int($total/1024);
  if ($total > 1048576){
    # CONVERT TO TB OUTPUT FOR CLARITY
    $displaytotal = $total / 1048576;
    $displaytotal = sprintf("%0.1f", $displaytotal);
    $displaytotal = "${displaytotal}tb";
  } elsif ($total > 1024) {
    # CONVERT TO GB OUTPUT FOR CLARITY
    $displaytotal = $total / 1024;
    $displaytotal = sprintf("%0.1f", $displaytotal);
    $displaytotal = "${displaytotal}gb";
  } else {
    # LESS THAN A GB TO REPORT, KEEP AS MB
    $displaytotal = "${total}mb";
  }
  # ------------> ends here

  # SET % FREE
  $invert = 100 - $percent;
  $invert = 99 if ($invert > 99);
  $percent = substr($percent,-1,1) if ($percent =~ m/^0/);
  #$percent = "${percent}%";
  #print "\t\t[${percent}% ($displayavail free) on $mount]\n" if ($D > 1);
  $fulltext .= "[${percent}% full, $displaytotal total $displayused used $displayavail free on $mount] ";
  $perftext .= "$mount=${percent}% | ";
  #print "\t\tModified output: [$displayavail (${invert}%) free on $mount]\n" if ($D > 0);
  if ($CP && $CP eq '%') {
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
# %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
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
-q		SNMP timeout in seconds (default timeout is $TMOUT seconds)
-z		SNMP retry count (default is $RETRYCNT)

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

