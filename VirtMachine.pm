package VirtMachine;

use Moose;
use MooseX::FollowPBP;
use File::Find;
use Data::Dumper;

# ==========
# PROPERTIES
# ==========

# name of virtual machine
has 'name' => (
	  isa		=> 'Str'
	, is		=> 'rw'
);

# backup device, currently /dev/sdg1
has 'savedevice' => (
	  isa		=> 'Str'
	, is		=> 'rw'
);

# where backups are saved to, typically /mnt/backup
has 'savepath' => (
          isa           => 'Str'
        , is            => 'rw'
);

# backup device filesystem type
has 'savedevicefs' => (
          isa           => 'Str'
        , is            => 'rw'
        , default       => 'ext3'
);

# one or more LVM volumes
has 'vols' => (
	  isa		=> 'ArrayRef'
	, is		=> 'ro'
);

# are volumes for VM included for backup - 1 (default) or 0
has 'isincluded' => (
	  isa		=> 'Int'
	, is		=> 'ro'
	, default	=> 1
);

# volume type: "lv (logical volume [default]) or fs (file system device)
has 'voltype' => (
          isa           => 'Str'
        , is            => 'ro'
        , default       => 'lv'
);

# one or more LVM volume blobs, names taken from "volumes"
has 'backupblobs' => (
	  isa		=> 'HashRef'
	, is		=> 'ro'
);

# where backups are saved to, typically /mnt/backup
has 'istest' => (
          isa           => 'Int'
        , is            => 'ro'
        , default	=> 0
);

# setting size of snapshot as percentage of original volume; default set to 15%
has 'snappercentage' => (
          isa           => 'Int'
        , is            => 'ro'
        , default	=> 15
);

# compress command
has 'compresswith' => (
          isa           => 'Str'
        , is            => 'ro'
);


# ==========
# METHODS
# ==========

# NOTE: setters and getters are automagically provided by MooseX::FollowPBP

sub takesnapshot {
	my ($self, $vol_ref, $cnt) = @_;
	my %vol = %{ $vol_ref };
	$self->mntdevice if ($cnt == 0);
	$cnt++;
	# print Dumper($self);
	
	my $snapshotsize = $vol{"snapsize"}.substr($vol{"lv_size_unit"}, 0, 1);
	my $snapshotname = $vol{"name"}."-snapshot";
	my $snapshotsource = "/dev/".$vol{"volgroup"}."/".$vol{"name"};
	
	print $cnt.") lvcreate -L ".$snapshotsize." -n ".$snapshotname." -s ".$snapshotsource."\n";
	# print "Take snapshot: ".$cnt."\n";
	return $cnt;
}

sub delsnapshot {
	my ($self, $vol_ref, $cnt) = @_;
	my %vol = %{ $vol_ref };
	# print Dumper($self);
	# print "Delete snapshot: ".$cnt."\n";
	print $cnt.") lvremove -f /dev/".$vol{"volgroup"}."/".$vol{"name"}."-snapshot\n";
	--$cnt;
	$self->unmntdevice if ($cnt == 0);
	return $cnt;
}

sub mntdevice {
	my ($self) = @_;
	my $device = $self->get_savedevice;
	my $path = $self->get_savepath;
	my $fstype = $self->get_savedevicefs;
	my $result;
	if ($self->get_istest == 1) {
		$result = "[TEST] mount -t $fstype $device $path";
	}
	else {
		$result = `mount -t $fstype $device $path`;
	}
	# print "mnt ".$self->getdevice." ".$self->getpath."\n";
	print "Device mount cmd: ".$result."\n";
}

sub unmntdevice {
	my ($self) = @_;
	my $path = $self->get_savepath;
	my $result;
	if ($self->get_istest == 1) {
		$result = "[TEST] umount $path";
	}
	else {
		$result = `umount $path`;
	}
	print "Device unmounted cmd: ".$result."\n";
}

# cleaning up
no Moose;
__PACKAGE__->meta->make_immutable;

1;
