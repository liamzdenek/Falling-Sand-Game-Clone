#!/usr/bin/perl
# Intellectual property of Liam Zdenek, 2011

# At least tell me if you're going to steal my code.
# But please don't steal my code.
use strict;
use warnings;
use SDL;
use SDLx::App;
use SDL::Event;
use POSIX qw/ floor ceil pow /;

my $width = 640;
my $height = 480;

require 'Pixel.pm';
require 'PhysicsType.pm';
require 'Grid.pm';

my @physics_types = (
	PhysicsType->new( # 0
		name => "air",
		color => sub { [0, 0, 0, 255] },
		null_physics => 0,
	),
	PhysicsType->new( # 1
		name => "sand",
		color => sub { [255, 255, 0, 255] },
		on_gravity => sub {
			my( $grid, $x, $y ) = @_;
			$grid->translate_pixel_available($x, $y, $x+int(rand(3))-1, $y+1);
		}
	),
	PhysicsType->new( # 2
		name => "rock",
		null_physics => 0,
		color => sub{ [140,69,19,255] } # 8b4513
	),
	PhysicsType->new( # 3
		name => "gas",
		color => sub { [16,80, 255, 255] }, # 1050ff
		on_gravity => sub {
			my( $grid, $x, $y ) = @_;
			$grid->translate_pixel_available($x, $y, $x+int(rand(3))-1, $y-1);# ||
			#floor(rand(2)) ?
			#$grid->translate_pixel_available($x, $y, $x+1, $y) :
			#$grid->translate_pixel_available($x, $y, $x-1, $y);
		}
	),
	PhysicsType->new( # 4
		name => "fire",
		color => sub { int(rand(3))-1 ? [255, 20, 20, 255] : [255, 255, 20, 255] },
		on_gravity => sub {
			my( $grid, $x, $y ) = @_;
			my $randoff = int(rand(3))-1;
			if( int(rand(2)) ) { $grid->set_pixel($x, $y, 0) }
			elsif(
					$grid->set_pixel_available($x+int(rand(3))-1, $y-int(rand(3))-1, 4) or
					$grid->get_pixel($x+$randoff, $y-1) == 2 and
					$grid->set_pixel($x+$randoff, $y-1, 4)
			) {
				$grid->set_pixel($x, $y, 0);
			}
		}
	),
	PhysicsType->new(
		name => "torch",
		color => sub { [255, 0, 0, 255] },
	)
	## IDEAS
	# fire spawn [torch]
	# water
	# water spawn [spout]
	# heater
	# steam
	# erase [destroy everything that touches it]
	# salt
	
);

my $g = Grid->new(
	default_type => 0,
	gravity_update_time => 1,
	physics_types => \@physics_types,
);

my $draw_type = 1;
my $TITLE = "Falling Sand Game Clone - ".$physics_types[$draw_type]->name;

my $app = SDLx::App->new(
	t => $TITLE,
	w => $width,
	h => $height,
	#resizeable => 1,
	eoq => 1,
);

my $is_mouse_down = 0;
$app->add_event_handler(
	sub {
		return 0 if $_[0]->type == SDL_QUIT;
		
		if($_[0]->type == SDL_MOUSEBUTTONDOWN || $is_mouse_down) {
			my $x = $_[0]->button_x;
			my $y = $_[0]->button_y;
			
			for my $xi (-5..5) {
				for my $yi (-5..5) {
					$g->set_pixel($x+$xi, $y+$yi, $draw_type);
				}
			}
			$is_mouse_down = 1;
		}
		if($_[0]->type == SDL_MOUSEBUTTONUP) {
			$is_mouse_down = 0;
		}
		if($_[0]->type == SDL_KEYDOWN) {
			if($_[0]->key_sym == SDLK_TAB) {
				$draw_type++;
				$draw_type = 0 if($draw_type > $#physics_types);
				$app->title("Falling Sand Game Clone - ".$physics_types[$draw_type]->name());
			}
		}
		
		return 1
	}
);

$app->add_show_handler(
	sub {
		$g->update($app);
		$app->update();
	}
);

$g->initialize($app);

$app->run();