#!/usr/bin/env perl

use warnings;
use strict;

use lib `pwd`;
# use threads;
# use threads::shared;
use Getopt::Long;
use Data::Dumper;
use VMCollection;

# Set umask
umask(0022);	# files to 0644 and dirs to 0755

my $configfile;

GetOptions (
	"config=s"	=> \$configfile		# supply full path of config file
) or die ("Error in command line arguments: ".$!."\n");

my $coll = VMCollection->new();		# create new object instance
$coll->createVMs($configfile);
$coll->takesnapshots;
$coll->createbackups;
$coll->delsnapshots;

# my $virtMachines_ref = createVMs(\$config);
# takesnapshots($virtMachines_ref);
# createbackups($virtMachines_ref);
# delsnapshots($virtMachines_ref);

