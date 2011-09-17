#!/usr/bin/env perl
# We want to know if this is going to explode in our face
use strict;

# We use this for the TUI
use Curses::UI;

# We use this stuff for authentication
use Net::LDAP;

# Config stuff
my $config = {
	ldap_server => 'ldap.cluenet.org',
	cluepoints_server => 'cluepoints.cluenet.org',
	cluepoints_port => 58945,
	login => {},
};

# Base UI
my $ui = new Curses::UI(
	-color_support => 1
);

# Menus
 my @ui_menus = (
	{
		-label => 'Shell',
		-submenu => [
			{
				-label => 'Exit      ^Q',
				-value => \&dialog_exit,
			},
		]
	},
);

# Add the menu to the UI window
my $ui_menu = $ui->add(
	'menu','Menubar',
	-menu => \@ui_menus,
	-fg => "blue",
);


# Dialogs
sub dialog_exit() {
	my $return = $ui->dialog(
		-message => "Do you really want to quit?",
		-title => "Are you sure?",
		-buttons => ['yes', 'no'],
	);

	if( $return ) {
		if( $config->{'login'}->{'username'} ) {
			$config->{'login'}->{'ldap'}->unbind();
		}
		exit(0);
	}
}

# Windows

# -- Main
my $main_window = $ui->add(
	"main_window", "Window",
	-border => 1,
	-title => 'Welcome back',
	-ipad => 2,
	-height => 15,
	-width => 60,
	-centered => 1,
);

# -- End main

# -- Login
my $login_window = $ui->add(
	"login_window", "Window",
	-border => 1,
	-title => 'Your passwords all belong to us.',
	-ipad => 2,
	-height => 15,
	-width => 60,
	-centered => 1,
);

# ---- username box
$login_window->add(
	'username_label', 'Label',
	-x => 0, -y => 4, -width => 13,
	-textalignment => 'right',
	-text => 'Username:',
);

$login_window->add(
	'username', 'TextEntry',
	-x => 14, -y => 4,
);

# ---- Password box
$login_window->add(
	'password_label', 'Label',
	-x => 0, -y => 6, -width => 13,
	-textalignment => 'right',
	-text => 'Password:',
);

$login_window->add(
	'password', 'TextEntry',
	-x => 14, -y => 6,
	-password => '*',
);

# ---- Login buttons
$login_window->add(
	'login_buttons', 'Buttonbox',
	-x => 14, -y => 8,
	-buttons => [
		{
			-label => '< Login >',
			-onpress => sub {
				my $this = shift;
				if( check_login_data($this) ) {
					if( login() ) {
						$this->parent->loose_focus;
					}
				}
			}
		},
		{
			-label => '< Quit >',
			-onpress => sub {
				exit(0);
			}
		},
	],
);

$login_window->modalfocus;
$ui->delete('login_window');

# -- End Login

# Subs

# This actually does the login
sub login {
	$ui->progress(
		-message => "Trying to login...",
		-max => 4,
		-pos => 1,
	);

	# Connect to LDAP
	$ui->setprogress(2, "Trying to connect to LDAP...");
	$config->{'login'}->{'ldap'} = Net::LDAP->new(
		$config->{'ldap_server'}
	);
	if( $@ ) {
		$ui->error("Could not connect to the LDAP server");

		$ui->noprogress();
		return;
	}

	# Try and bind to LDAP
	$ui->setprogress(4, "Trying to bind to LDAP...");
	my $mesg = $config->{'login'}->{'ldap'}->bind(
		'uid=' . ldap_escape($config->{'login'}->{'username'}) . ',ou=people,dc=cluenet,dc=org',
		password => $config->{'login'}->{'password'},
	);

	if($mesg->code != '0') {
		$ui->error("Could not bind to LDAP: " . $mesg->error);

		$ui->noprogress();
		return;
	}

	return 1;
}

# This validates the form data
sub check_login_data {
	my $buttons = shift;

	foreach my $field ('username', 'password') {
		my $obj = $login_window->getobj($field);
		my $value = $obj->get;
		$config->{'login'}->{$field} = $value;

		if ($value =~ /^\s*$/) {
			$ui->error("Missing value for $field field");
			$obj->focus;
			return;
		}
	}
	return 1;
}

# Ldap escape
sub ldap_escape {
	my $string = shift;
	$string =~ s/\*/\\2a/g;
	$string =~ s/\(/\\28/g;
	$string =~ s/\)/\\29/g;
	$string =~ s/\\/\\5c/g;
	$string =~ s/\0/\\00/g;
	return $string;
}

# Get clue points
sub get_cluepoints {
	my $nick = shift;
	my $points_socket = IO::Socket::INET->new(
		PeerAddr => $config->{'cluepoints_server'},
		PeerPort => $config->{'cluepoints_port'},
	) or return;

	$nick =~ s/\r/\\r/g;
	$nick =~ s/\n/\\n/g;
	$points_socket->send("points $nick\r\n");

	my $data = '';
	$points_socket->recv($data, 1024);
	$points_socket->close();

	my @points = split(/:/, $data);
	return $points[0];
}

# Main code
$ui->set_binding(sub {$ui_menu->focus()}, "\cX");
$ui->set_binding(\&dialog_exit, "\cQ");

$login_window->focus();
$ui->mainloop();
