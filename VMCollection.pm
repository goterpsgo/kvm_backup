package VMCollection;

use lib `pwd`;
use Linux::LVM;
use File::Find;
use Data::Dumper;
use Math::Round qw(round);
use VirtMachine;
use JSON;
use Moose;
use MooseX::FollowPBP;
# use Moose::Util::TypeConstraints;

my $cntVols :shared = 0;		# counter is iterated as soon as a volume snapshot is created; shared with all VirtMachine objects



# array containing one or more VirtMachine child objects
has 'virtmachines' => (
	  isa		=> 'ArrayRef'
	, default	=> sub{[]}
	, is		=> 'rw'
);



# dies if mandatory params are missing from config file
sub _checkconfig {
	my ($self, $config_ref) = @_;
	my @missingvalues;
	my %fieldsneeded = qw(savedevice 1 savepath 1);	# missing field values wil cause validation to fail
	
	foreach my $field (sort keys %fieldsneeded) {
		push (@missingvalues, $field) if (! $$config_ref->{$field});
	}
	
	if ((scalar @missingvalues) > 0) {
		die "[ERROR] Missing mandatory values in config file: ".join(", ", @missingvalues).".  Exiting.\n";
	}
}



# gathers a VM's volume(s) information and saves it to %hash
sub _returnvols {
	my ($self, $vm_ref) = @_;
	my $name = $vm_ref->{name};
	my $voltype = $vm_ref->{voltype};
	
	Linux::LVM->units('M');		# size values in megabytes
	my @vols;
	
	# valid values for $voltype are "lv" and "fs"
	if ($voltype eq "lv") {
		# return volumn list using system tools
		my @vgs = get_volume_group_list();
		foreach my $vg (@vgs) {
			my %lv = get_logical_volume_information($vg);
			foreach my $lvname (sort keys %lv) {
				my %hash;
				foreach(sort keys %{$lv{$lvname}}) {
					$hash{$_} = $lv{$lvname}->{$_};
				}
				# push to @vols if volname from config matches that from system
				if ($hash{"name"} =~ /$name/) {
					$hash{"volgroup"} = $vg;
					push (@vols, \%hash);
				}
			}
		}
	}
	else {
		# return volume list using config file params
		my $cntVols = (scalar @{ $vm_ref->{vols} });
		die "No vols included in config for fs-based VM [$name].  Exiting.\n" if ($cntVols == 0);
		@vols = @{ $vm_ref->{vols} };
	}
	
	return \@vols;
}



# instantiates VM objects based on values saved in $configfile
sub createVMs {
	my ($self, $configfile) = @_;
	
	my $json;
	
	# read in JSON config file
	{
		local $/;
		open my $fh, "<", $configfile;
		$json = <$fh>;
		close $fh;
	}

	my $config = decode_json($json);	# create config hash
	
	$self->_checkconfig(\$config);
	my $listOfVMs_ref = $config->{virtmachines};

	# create VMs on the fly and save them to @virtMachines, but only the ones where isincluded == 1
	my @virtMachines = ();
	foreach my $vm ( @$listOfVMs_ref ) {
		push (@virtMachines, VirtMachine->new(		# cast object method as array (not casting would result in error)
			  name			=> $vm->{name}
			, voltype		=> $vm->{voltype}
			, savepath		=> $config->{savepath}
			, savedevice		=> $config->{savedevice}
			, savedevicefs		=> $config->{savedevicefs}
			, istest		=> $config->{istest}
			, snappercentage	=> $config->{snappercentage}
			, compresswith		=> $config->{compresswith}
			, vols			=> $self->_returnvols($vm)
		)) if ($vm->{isincluded} == 1);
	}

	$self->set_virtmachines(\@virtMachines);	# save @virtMachines to VMCollection::virtmachines
}



# loops through collection of VMs, extracts volumes from each, and takes a snapshot
sub takesnapshots {
	my ($self) = @_;
	
	foreach my $vm (@{$self->get_virtmachines}) {
		foreach my $vol (@{ $vm->{vols} }) {
			$vol->{snapsize} = ( round( ($vm->{snappercentage} / 100) * $vol->{lv_size} ) );
			# print Dumper($virtMachines_ref);
			# ${$vol}->{snappercentage} = ${$virtMachines_ref}->{snappercentage};
			lock($cntVols);
			$cntVols = $vm->takesnapshot($vol, $cntVols);
			# print "Value: ".$cntVols."\n";
		}
	}
}



# loops through collection of VMs, and backs up logical volumes to backup device
sub createbackups {
	my ($self) = @_;
	
	foreach my $vm (@{$self->get_virtmachines}) {
		foreach my $vol (@{ $vm->{vols} }) {
		}
	}
}



# loops through collection of VMs, extracts volumes from each, and deletes appropriate snapshot
sub delsnapshots {
	my ($self) = @_;
	
	foreach my $vm (@{$self->get_virtmachines}) {
		foreach my $vol (@{ $vm->{vols} }) {
			lock($cntVols);
			$cntVols = $vm->delsnapshot($vol, $cntVols);
			# print "Value: ".$cntVols."\n";
		}
	}
}

# cleaning up
no Moose;
__PACKAGE__->meta->make_immutable;

1;
