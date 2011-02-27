package Pixel;
use Moose;

has 'type' => (
	is      => "rw",
	isa     => "Int",
	trigger => sub {
		my( $self, $new, $old ) = @_;
		if(defined $old) {
			$self->previous_type($old);
		}
		$new
	}
);

has 'previous_type' => (
		is  => "rw",
	isa => "Num"
);

1;