package Grid;
use Moose;
use SDL;
use SDLx::App;
use Inline with => 'SDL';
use Time::HiRes qw/ time /;
use POSIX qw/ floor ceil pow /;

has 'grid' => (
	is => "rw",
	isa => "ArrayRef",
	default => sub{ [] },
);

has 'edits' => (
	is => "rw",
	isa => "ArrayRef",
	default => sub{ [] },
);

has 'default_type' => (
	is => "rw",
	isa => "Int",
	default => 0,
);

has 'gravity_update_time' => (
	is => "rw",
	isa => "Num",
	required => 1
);

has 'last_gravity_update' => (
	is => "rw",
	isa => "Num",
	default => 0,
);

has 'physics_types' => (
	is => "rw",
	isa => "ArrayRef",
	required => 1,
);

has 'locations' => (
	is => "rw",
	isa => "ArrayRef",
	default => sub{ [] }
);

has 'app' => (
	is => "rw",
);

my $GRAVITY_UPDATE_FREQUENCY = .1;

sub initialize {
	my( $self, $app ) = @_;
	$self->app($app);
	print "Initializing...\n";
	WIDTH: for my $x (0..$app->w-1) {
		HEIGHT: for my $y (0..$app->h-1) {
			$self->render_pixel($app, $x, $y, @{ $self->physics_types->[$self->default_type]->color->($self,$x, $y) } );
		}
	}
	print "Initialized\n";
}

our @updatelog = ();

sub update {
	my( $self ) = @_;
	my $app = $self->app;
	my $update_gravity = $self->last_gravity_update + $GRAVITY_UPDATE_FREQUENCY < time();
	my $starttime = time();
	if($self->last_gravity_update + $GRAVITY_UPDATE_FREQUENCY < time()) {
		my $count = 0;
		for my $t ( 0..@{ $self->physics_types }) {
			next if(!defined $self->physics_types->[$t]);
			next if(!$self->physics_types->[$t]->null_physics);
			for my $x ( keys %{$self->locations->[$t]} ) {
				for my $y ( keys %{$self->locations->[$t]{$x}} ) {
					$self->physics_types->[$t]->on_gravity->($self, $x, $y);
					$count++;
				}
			}
		}
		$self->last_gravity_update(time());
		my $endtime = time();
		print "COUNT $count = ".($endtime-$starttime)."\n";
		$updatelog[$count] = $endtime-$starttime;
	}
	
	my @edits = @{ $self->edits };
	#print "EDITS: ".int(@edits)."\n";
	$self->lock($app);
	for( @edits ) {
		my( $x, $y, $type ) = @{ $_ };
		for my $t (0..@{ $self->locations }) {
			delete($self->locations->[$t]{$x}{$y});
		} 
		$self->locations->[$type]{$x}{$y} = 1;
		defined $self->grid->[$x][$y] ?
			$self->grid->[$x][$y]->type($type) :
			$self->grid->[$x][$y] = Pixel->new(
				type => $type,
			);
		my @color = @{$self->physics_types->[$type]->color->($x, $y)};
		$self->render_pixel($app, $x, $y, @color);
	}
	$self->unlock($app);
	$app->update();
	$self->edits([]);
}

use Inline C => <<'RENDER_FUNC';

void lock ( float delta, SDL_Surface *screen )
{
	if (SDL_MUSTLOCK(screen)) 
		if (SDL_LockSurface(screen) < 0) 
			return;
}

void unlock ( float delta, SDL_Surface *screen )
{
	// Unlock if needed
	if (SDL_MUSTLOCK(screen)) 
		SDL_UnlockSurface(screen);
	// Tell SDL to update the whole screen
	SDL_UpdateRect(screen, 0, 0, screen->w,screen->h);
}

void render_pixel( float delta, SDL_Surface *screen, int x, int y, Uint8 r, Uint8 g, Uint8 b, Uint8 a)
{
	int ofs = _calc_offset(screen, x, y);
	Uint32 map_val = SDL_MapRGBA( screen->format, r, g, b, a);
	((unsigned int*)screen->pixels)[ofs] = map_val;
}

int _calc_offset ( SDL_Surface* surface, int x, int y )
{
    int offset;
    offset  = (surface->pitch * y)/surface->format->BytesPerPixel;
    offset += x;
    return offset;
}

RENDER_FUNC

sub translate_pixel_available {
	my( $self, $x1, $y1, $x2, $y2 ) = @_;
	return $self->translate_pixel($x1, $y1, $x2, $y2) if($self->pixel_available($x2,$y2));
	return 0;
}

sub pixel_available {
	my( $self, $xo, $yo ) = @_;
	my $is_found = 0;
	return 0 if(!$self->_is_within_bounds($xo, $yo));
	for( @{ $self->edits } ) {
		my( $x, $y, $type ) = @{ $_ };
		if($x == $xo and $y == $yo) {
			return 0;
		}
	}
	if($self->get_pixel($xo, $yo) == $self->default_type) {
		return 1;
	}
	return 0;
}

sub translate_pixel {
	my( $self, $x1, $y1, $x2, $y2 ) = @_;
	$self->set_pixel($x1, $y1, $self->default_type);
	$self->set_pixel($x2, $y2, $self->get_pixel($x1, $y1));
	1;
}

sub set_pixel_available {
	my( $self, $x, $y, $type ) = @_;
	return $self->set_pixel($x, $y, $type) if($self->pixel_available($x, $y));
	return 0;
}

sub _is_within_bounds {
	my( $self, $x, $y ) = @_;
	return 0 if(
		$x > $self->app->w-1 or
		$y > $self->app->h-1 or
		$x < 0 or
		$y < 0
	);
	return 1;
}

sub set_pixel {
	my( $self, $x, $y, $type ) = @_;
	return 0 if(!$self->_is_within_bounds($x, $y));
	my $old_type = $self->get_pixel($x, $y);
	push @{ $self->edits }, [$x, $y, $type];
	$self->physics_types->[$old_type]->on_destroy->($self, $x, $y, $type);
	$self->physics_types->[$type]->on_create->($self, $x, $y, $type);
	return 1;
}

sub get_pixel {
	my( $self, $x, $y ) = @_;
	return 0 if(!$self->_is_within_bounds($x, $y));
	return defined $self->grid->[$x][$y] ? $self->grid->[$x][$y]->type : $self->default_type;
}

1;