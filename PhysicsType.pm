package PhysicsType;
use Moose;
has 'null_physics' => (
	is => "rw",
	isa => "Bool",
	default => 1
);
has 'on_create'   => (
	is => "rw",
	isa => "CodeRef",
	default => sub{ sub{} },
);
has 'on_destroy'  => (
	is => "rw",
	isa => "CodeRef",
	default => sub{ sub{} },
);
has 'color'       => (
	is => "rw",
	isa => "CodeRef",
	required => 1,
);
has 'on_update'   => (
	is => "rw",
	isa => "CodeRef",
	default => sub{ sub{} },
);
has 'on_gravity'  => (
	is => "rw",
	isa => "CodeRef",
	default => sub{ sub{} },
);
has 'update_time' => (
	is => "rw",
	isa => "Num",
	default => 999,
);
has 'name' => (
	is => "rw",
	isa => "Str",
	default => "Untitled Element",
);
1;