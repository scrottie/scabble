
use Continuity;
use Continuity::Adapt::HttpDaemon;
use Continuity::Mapper;

use Event;
use Coro::Event;

use IO::Handle;
use List::Util 'shuffle', 'min', 'max';
use Scalar::Util 'blessed';
use Storable 'nstore', 'retrieve';

use strict;
use warnings;

#          .__        ___.          .__              __          __          
#     ____ |  |   ____\_ |__ _____  |  |     _______/  |______ _/  |_  ____  
#    / ___\|  |  /  _ \| __ \\__  \ |  |    /  ___/\   __\__  \\   __\/ __ \ 
#   / /_/  >  |_(  <_> ) \_\ \/ __ \|  |__  \___ \  |  |  / __ \|  | \  ___/ 
#   \___  /|____/\____/|___  (____  /____/ /____  > |__| (____  /__|  \___  >
#  /_____/                 \/     \/            \/            \/          \/

# misc config

my $poll_time = 30; # how long to dally answering update requests when no updates are available

# error handling

use Carp; $SIG{__DIE__} = sub { confess; };
sub failure ($) { my $msg = shift; STDERR->print($msg, "\n"); return undef; }
$SIG{PIPE} = sub { };

# server

my $server = Continuity->new( 
    # adaptor => Continuity::Adapt::HttpDaemon->new( LocalPort => 8000, ), 
    # staticp => sub { $_[0]->url->path =~ m/(jpg|gif|png|css|js)$/; },
    # staticp => sub { $_[0]->url =~ m/(jpg|gif|png|css|js)$/; },
    port => 11704,
    callback => sub { main(@_) },
    # docroot => '/usr/home/scott/public_html/illum',
    debug => 1,
    mapper   => Continuity::Mapper->new(
        callback => \&main,
        path_session => 1,
        ip_session => 1,
        # cookie_session => 'sid',
    ),
);

# my $url = $server->{adaptor}->{daemon}->url;
# $url = `hostname` =~ m/straylight/ ? 'http://slowass.net:8000' : 'http://localhost:8000'; # XXX
my $url = "http://slowass.net:11704";

# initial card layout

my $board = board->new( board_x => 1600, board_y => 1700, );

(my $card_x, my $card_y) = (170, 118); 

# action pads

$board->move_past;

(my $turnover_x, my $turnover_y) = (10, 10);
$board->move_past;

(my $reveal_x, my $reveal_y) = (180, 10);
$board->move_past;

# movement deltas

my @actions; # history of all movements used to send deltas -- contains intances of the action class.

#

my $shuffle_cards;

do {

    # game board
    $board->add( card->new( back_img => '/jpg/scrabblebig.jpg', front_img => '/jpg/scrabblebig.jpg', card_x => 1280, card_y => 1051, id => 'scrabble', x => 0, y => 200,  ) );

    my @cards;

    my $letter = sub {
        my $let = shift; 
        my $card = card->new( front_img => "/jpg/${let}.png", back_img => "/jpg/_.png", hid => 1, card_x => 57, card_y => 57 ); 
        push @cards, $card;
        $board->add($card); 
    };
    $letter->('_') for 1..2;
    $letter->('a') for 1..9;
    $letter->('b') for 1..3;
    $letter->('c') for 1..2;
    $letter->('d') for 1..3;
    $letter->('e') for 1..12;
    $letter->('f') for 1..2;
    $letter->('g') for 1..3;
    $letter->('h') for 1..2;
    $letter->('i') for 1..9;
    $letter->('j') for 1..1;
    $letter->('k') for 1..1;
    $letter->('l') for 1..4;
    $letter->('m') for 1..2;
    $letter->('n') for 1..6;
    $letter->('o') for 1..8;
    $letter->('p') for 1..2;
    $letter->('q') for 1..1;
    $letter->('r') for 1..6;
    $letter->('s') for 1..4;
    $letter->('t') for 1..6;
    $letter->('u') for 1..4;
    $letter->('v') for 1..2;
    $letter->('w') for 1..2;
    $letter->('x') for 1..1;
    $letter->('y') for 1..2;
    $letter->('z') for 1..1;
#    my $dir;
#    opendir $dir, 'jpg' or die $!;
#    for my $img (grep /^[a-z_].png$/, readdir $dir) {
#        push @cards, card->new( 
#            front_img => "/jpg/$img", back_img => "/jpg/_.png", hid => 1, card_x => 57, card_y => 57,
#        );
#    }

    #$board->layout_x = 50;
    #$board->layout_y = 50;
    #$board->cur_x = 350;
    #$board->cur_y = 10;

    $shuffle_cards = sub {

        (my $start_z) = map $_->z, min grep $_->z, @cards;
warn "start_z = $start_z";

        @cards = shuffle @cards;
        for my $card (@cards) {
            # put the card face down
            if( ! $card->hid ) {
                $card->hid = 1;
                push @actions, action->new( type => 3, card => $card, player_id => '*system', text => 'shuffle: flip the tile back over');
            }
            # move the cards around in the pile
            $card->x = 400 + 50 + int(rand(50)) - 25 + int(rand(50)) - 25 + int(rand(60)) - 30;
            $card->y = 60 + int(rand(50)) - 25 + int(rand(50)) - 25 + int(rand(60)) - 30;
            $card->z = $start_z++;
            push @actions, action->new( type => 1, card => $card, player_id => '*system', text => 'shuffle: ' . $card->x . ', ' . $card->y);
        }
    };

    $shuffle_cards->();

};

# restore game position

if(-f "$0.board.store") {
    $board = retrieve("$0.board.store");
}

# backups

async {
    my $timer = Coro::Event->timer( interval => 300, );
    my $delta = 0;
    while(1) {
        $timer->next;
        $delta == @actions and next;
        $delta = @actions;
        nstore $board, "$0.board.store";  
    }
};

# players

my @players;

#                                .__                        
#  _______ __ __  ____           |  |   ____   ____ ______  
#  \_  __ \  |  \/    \   ______ |  |  /  _ \ /  _ \\____ \ 
#   |  | \/  |  /   |  \ /_____/ |  |_(  <_> |  <_> )  |_> >
#   |__|  |____/|___|  /         |____/\____/ \____/|   __/ 
#                    \/                             |__|  

Event::loop;

sub main {
    my $request = shift; # null initial request that only has the queue object in it
    # $request = $request->next;
    my $action;
    goto next_request if $request->param('action') and $request->param('action') eq 'updator';  # XXX kluge... running two apps, and making both log in would suck, so player_id is just passed, and right now, without a secure hash on it either
    (my $player_id, $request) = login($request);
    frameset($request, $player_id);
    next_request:
    $action = $request->param('action') || 'frameset';
    # $request->print("action: ", $request->param('action'), "\n");
    STDERR->print('-' x 30, ' ', $request->{request}->uri, ' ', '-' x 30, "\n");
    main->can($action) and main->can($action)->($request, $player_id);
    $request = $request->next;
    goto next_request;
}

#                  __  .__                      
#   _____    _____/  |_|__| ____   ____   ______
#   \__  \ _/ ___\   __\  |/  _ \ /    \ /  ___/
#    / __ \\  \___|  | |  (  <_> )   |  \\___ \ 
#   (____  /\___  >__| |__|\____/|___|  /____  >
#        \/     \/                    \/     \/ 

sub login {
    my $request = shift;
    my $greeting;

    login_screen:
    ($greeting) = map $_->[rand @{$_}], [
        "dear fellow",
        "good chap",
        "sport",
    ];
    $request->print(qq{
        Okay, do be a $greeting and tell me who you are.<br>
        <form method="post">
            <input type="text" name="player_id"> &lt;-- name <br>
            <input type="password" name="password"> &lt;-- password (make one up to create an account, accounts are very transient)<br>
            <input type="password" name="gamepass"> &lt;-- password to join the game<br>
            <input type="submit" value="Go">
    });

    # check password

    $request = $request->next;

    my $player_id = $request->param('player_id') or do { $request->print("No name entered...<br>\n"); goto login_screen; };
    my $password = $request->param('password') or do { $request->print("No password entered...<br>\n"); goto login_screen; };
    $request->param('gamepass') eq 'wee' or do { $request->print("No gamepass entered or wrong gamepass...<br>\n"); goto login_screen; };

    (my $illegal) = $player_id =~ m{([^a-zA-Z0-9 -])};
    if(defined $illegal) {
        $illegal = '&' . ord($illegal) . ';';
        $request->print(qq{Character $illegal is forbidden (or, more correctly, not explicitly permitted) for use in names.<br>\n});
        goto login_screen;
    }

    (my $player) = grep $_->player_id eq $player_id, @players;
    if(! $player) {
        push @players, player->new( player_id => $player_id, password => $password );
        $request->print(qq{Welcome, new player $player_id.<br>\n});
    # } elsif( ! blessed $player or! $player->isa('player')) {
    #     STDERR->print("not-a-player\n");
    } elsif( $player->password eq $password ) {
        $request->print(qq{Welcome back, $player_id.<br>\n});
    } else {
        $request->print(qq{Sorry, $player_id exists and that wasn't the right password.<br>\n});
        goto login_screen;
    }

    $request->print(qq{
        <br>
        Information about this game: <a href="http://slowass.net/blogs/illum/" target="aboutwin">blog</a> 
        <br>
        <a href="$url">Enter game</a><br>
    });

    push @actions, action->new( type => 0, text => "logs in", player_id => $player_id, );

    return ($player_id, $request);

}

sub frameset {
    my $request = shift;
    my $player_id = shift;
    $request->print(qq{
        <frameset rows="28,28,*">
            <frame frameborder="0" name="evil" src="$url/updator?action=updator&generation=@{[ scalar @actions ]}&player_id=$player_id">
            <frame frameborder="0" name="control" src="$url/?action=control">
            <frame frameborder="0" name="good" src="$url/?action=board">
        </frameset>
    });
}

sub control {
    # frame with links to reset etc
    my $request = shift;
    $request->print(qq{<!-- <a href="http://slowass.net/blogs/illum/" target="aboutwin">blog</a> / --><a href="$url/?action=game_log" target="gamelogwin">game log</a> / <a href="$url/?action=reset">reset game</a>\n});
    # $request->print(qq{<!-- <a href="http://slowass.net/blogs/illum/" target="aboutwin">blog</a> / --><a href="$url/?action=game_log" target="gamelogwin">game log</a> / <a href="#" onclick=top.good.do_request('$url/?action=reset', function () { }); return false;">reset game</a>\n});
    # it turns out that onclick actions get disabled/aborted as soon as the page refreshes from the server, which happens in the COMET frame one second how we have it set (then it hangs in COMET for a while).  the blog link also doesn't work while hanging for the server. XXX the proper fix for this is to stop doing COMET for HTML with JS in it and instead do AJAX COMET requests for data in the background.
}

sub board {
    # redraw the board
    # go through all of the cards and output HTML for them
    my $request = shift;
    $request->print(<<EOF);
        <head>
        </head>
        <body bgcolor="white">
            <script language="javascript" src="dom-drag.js"></script>
            <script language="javascript" src="ajax.js"></script>
            <table width="$board->{board_x}" height="$board->{board_y}"><tr><td width="$board->{board_x}" height="$board->{board_y}">
            <!-- turnover pad  -->
            <div style="position: absolute; width: ${card_x}px; height: ${card_y}px; left: ${turnover_x}px; top: ${turnover_y}px; z-index: 0;">
                <table width="100%" height="100%"><tr><td bgcolor="green">Drop cards here to turn them over</td></tr></table>
            </div>
            <!-- reveal pad  -->
            <div style="position: absolute; width: ${card_x}px; height: ${card_y}px; left: ${reveal_x}px; top: ${reveal_y}px; z-index: 0;">
                <table width="100%" height="100%"><tr><td bgcolor="blue">Drop cards here to peek at them</td></tr></table>
            </div>
            <!-- ajax glue -->
            <script language="javascript">
                function do_request2(querystring, cb) {
                    do_request('$url/' + querystring + '&action=move', cb);
                };
                function handle_reply(page) {
                    // currently, do nothing...
                };
            </script>
            <!-- game pieces -->
EOF
    # <script language="javascript" src="dom-drag.js"></script>
    # <img id="navro" onload="Drag.init(this);" src="images/brickwallRO.jpg" style="position:absolute; left: 621px; top: 10px; z-index: 1000;">
    for my $card ($board->cards) {
        $request->print(qq{
            <img id="$card->{id}" alt="$card->{id}" src="@{[ $card->image ]}" style="position:absolute; left: $card->{x}px; top: $card->{y}px; z-index: $card->{z}; width: $card->{card_x}px; height: $card->{card_y}px;" onload="Drag.init(this);" >
        });
    }
    $request->print(qq{
            </td></tr></table>
        </body>
    });
}

sub move {
    # move a card
    # this action is called from the HTML output by board() above
    my $request = shift;
    my $player_id = shift;
    my $id = $request->param('id') or return failure "no id";
    my $x = $request->param('x');
    my $y = $request->param('y');
    my $card = $board->card_by_id($id) or return failure "can't find card for id $id";
STDERR->print("move request: id: $id x: $x y: $y\n");
    $card->x = $x; $card->y = $y;
    push @actions, action->new( type => 1, card => $card, player_id => $player_id, text => $card->x . ', ' . $card->y);
    if(overlaps( $x, $y, $turnover_x, $turnover_y, $card_x, $card_y, )) {
        # card was landed in the turn-over pad
        # 0 -- comment, 1 -- move, 2 -- rotation, 3 -- turn over, 4 -- peek
        $card->hid = ! $card->hid;
        push @actions, action->new( type => 3, card => $card, player_id => $player_id, );
    }
    if(overlaps( $x, $y, $reveal_x, $reveal_y, $card_x, $card_y, )) {
        push @actions, action->new( type => 4, card => $card, player_id => $player_id, );
    }
    if($card->can('roll')) {
        # oh, it's dice!
        $card->do_roll();
        push @actions, action->new( type => 5, card => $card, player_id => $player_id, text => $card->roll, );
    }
    $request->print("ok\n");  # or else AJAX doesn't work when there's no output XXX
}

sub updator {
    # check for movement and send commands to update the playfield
    my $request = shift;
    my $player_id = $request->param('player_id');
    my $generation = $request->param('generation');
    $request->print(qq{Alpha/testing Illuminati server / sync: }, scalar @actions, "\n");
    if($poll_time) {
        # dally on responding to the request until $poll_time seconds have passed or something changes
        my $timer = Coro::Event->timer( interval => 1, );
        my $give_up = $poll_time;
        while($generation == @actions and $give_up-- > 0) {
            # STDERR->print("debug: $con_num sleeping...\n");
            $timer->next;
        }
    }
    $request->print(qq{
        <meta http-equiv="refresh" content="2;url=$url/updator?action=updator&generation=@{[ scalar @actions ]}&player_id=@{[ escape($player_id) ]}">
        <!-- XXX rather than that, should just do something javascript timeout stuff that makes sure the main page is loaded first before request movement events! -->
        <script language="javascript">
    }) or return;
    while($generation < @actions) {
        my $action = $actions[$generation];
        # 0 -- comment, 1 -- move, 2 -- rotation, 3 -- flip card, 4 -- reveal
        if($action->type == 1 and $action->player_id ne $player_id) {
            # move a card
            # XXX experimental -- don't repeat move requests to people who initiated them as it just makes them have trouble moving it again
# XXX this is trying (and failing) to run before top.good.document has loaded.
            $request->print(qq{
                // probably should be top.good.getElementById rather than document
                top.good.document.getElementById('$action->{card}->{id}').root.style.left = '$action->{card}->{x}px';
                top.good.document.getElementById('$action->{card}->{id}').root.style.top = '$action->{card}->{y}px';
                top.good.document.getElementById('$action->{card}->{id}').root.style.zIndex = '$action->{card}->{z}';
            }) or return;
        } elsif(0 == 2) {
            # XXX rotation is a combination of changing the image and changing the image width and height
        } elsif($action->type == 3) {
            # flip a card over for all to see
            $request->print(qq{
                top.good.document.getElementById('$action->{card}->{id}').root.src = '@{[ $action->card->image ]}';
            }) or return;
        } elsif($action->type == 4) {
            STDERR->print("debug: peeking at a card: $player_id vs @{[ $action->player_id ]}\n");
            if($player_id eq $action->player_id) {
                # reveal a card to its owner only
                $request->print(qq{
                    window.open("@{[ $url . $action->card->front_img ]}", "@{[ $action->card->id ]}", "innerWidth=@{[ $action->card->card_x ]},innerHeight=@{[ $action->card->card_y ]}");
                }) or return;
            }
        } elsif($action->type == 5) {
            # dice roll
            $request->print(qq{
                top.good.document.getElementById('$action->{card}->{id}').root.style.left = '$action->{card}->{x}px';
                top.good.document.getElementById('$action->{card}->{id}').root.style.top = '$action->{card}->{y}px';
                top.good.document.getElementById('$action->{card}->{id}').root.src = '@{[ $action->card->image ]}';
            }) or return;
        }
    } continue {
        $generation++;
    }
    $request->print(qq{
        </script>
    }) or return;
}

sub game_log {
    # display a transcript of everything that has happened so far -- the main game board would
    # probably link to this in a pop-up window
    my $request = shift;
    my $player_id = $request->param('player_id');
    $request->print("<b>Game log, actions in reverse order:</b><br>\n");
    for my $action (reverse @actions) {
        $request->print( $action->desc, "<br>\n" );
    }
}

sub reset {
    my $request = shift;
    my $player_id = $request->param('player_id');
    $shuffle_cards->();
    control( $request );
}

#           __  .__.__  .__  __  .__               
#    __ ___/  |_|__|  | |__|/  |_|__| ____   ______
#   |  |  \   __\  |  | |  \   __\  |/ __ \ /  ___/
#   |  |  /|  | |  |  |_|  ||  | |  \  ___/ \___ \ 
#   |____/ |__| |__|____/__||__| |__|\___  >____  >
#                                        \/     \/ 

sub overlaps {
    my $x = shift;
    my $y = shift;
    my $tx = shift;
    my $ty = shift;
    my $card_x = shift;
    my $card_y = shift;
    if($x > $tx - $card_x/3 and $x < $tx + $card_x and
       $y > $ty - $card_x/3 and $y < $ty + $card_y) {
        return 1;
    } else {
        return 0;
    }
}

sub escape {
    my $value = shift;
    $value =~ s{([^a-zA-Z0-9])}{ '%' . sprintf '%02x', ord $1 }sge;
    return $value;
}

#        ___.        __               __          
#    ____\_ |__     |__| ____   _____/  |_  ______
#   /  _ \| __ \    |  |/ __ \_/ ___\   __\/  ___/
#  (  <_> ) \_\ \   |  \  ___/\  \___|  |  \___ \ 
#   \____/|___  /\__|  |\___  >\___  >__| /____  >
#             \/\______|    \/     \/          \/ 

package board;

use Data::Alias;

sub new { 
    my $pack = shift; 
    bless { 
        cards => [ ],                              # all of the game cards on the board
        board_x => 2000, board_y => 2000,          # total size of the board
        cur_x => 0, cur_y => 0, cur_layer => 1,    # current position on the board we're laying cards out at
        layout_x => 20, layout_y => 100,           # how much space to give each card for the purpose of laying it out
        @_,                                        # user-supplied values override ours
    }, $pack; 
}
#    for my $method (qw/card_x board_x board_y cur_x cur_y cur_layer layout_x layout_y/) {
#        *{$method} = sub :lvalue { my $self = shift; $self->{$method}; };
#    }
sub card_x :lvalue { $_[0]->{card_x} }
sub board_x :lvalue { $_[0]->{board_x} }
sub board_y :lvalue { $_[0]->{board_y} }
sub cur_x :lvalue { $_[0]->{cur_x} }
sub cur_y :lvalue { $_[0]->{cur_y} }
sub cur_layer :lvalue { $_[0]->{cur_layer} }
sub layout_x :lvalue { $_[0]->{layout_x} }
sub layout_y :lvalue { $_[0]->{layout_y} }
sub add {
    my $self = shift;
    my $card = shift;
    $card->id or $card->id = sprintf 'card%03d', $self->cur_layer;
    if(! $card->card_x or ! $card->card_y ) {
        die; # cards must know their width/height and we won't cache it for them
    }
    $self->card_x = $card->card_x; # just for edge of board detection in flowing layouts
    if(! defined $card->x or ! defined $card->y ) {
        warn "automatically positioning " . $card->id;
        $card->x = $board->cur_x; $card->y = $board->cur_y;
        $self->advance_position();
    }
    $card->z or do { $self->cur_layer++; $card->z = $self->cur_layer; };
    push @{ $self->{cards} }, $card; 
}
sub advance_position {
    my $self = shift;
    $self->cur_x += $self->layout_x; 
    if($self->cur_x + $self->card_x + 1 >= $self->board_x) {
        $self->new_line();
    }
    ($self->cur_x, $self->cur_y);
}
sub move_past {
    # like advance position, but move clear off of the area occupied by whatever we just placed -- use card_x instead of layout_x
    my $self = shift;
    $self->cur_x += $self->card_x;
    if($self->cur_x + $self->card_x + 1 >= $self->board_x) {
        $self->new_line();
    }
    ($self->cur_x, $self->cur_y);
}
sub new_line {
    my $self = shift;
    $self->cur_y += $self->layout_y;
    $self->cur_x = 0; 
    ($self->cur_x, $self->cur_y);
}
sub cards { @{ $_[0]->{cards} } }
sub card_by_id { my $self = shift; my $id = shift; for my $card ( $self->cards ) { return $card if $card->id eq $id; } }
# sub AUTOLOAD { $AUTOLOAD =~ m/::(.*)/; return if $1 eq 'DESTROY'; my $self = shift; $self->can($1)->($self, @_); }

package action;

sub new { my $pack = shift; bless { @_ }, $pack; }
sub type :lvalue { $_[0]->{type} }  # 0 -- comment, 1 -- move, 2 -- rotation, 3 -- img update (faceup/down), 4 -- reveal, 5 -- roll
sub card :lvalue { $_[0]->{card} }  # reference to the card that's been moved, revealed, or whatever
sub text :lvalue { $_[0]->{text} }  # comment on the move
sub player_id :lvalue { $_[0]->{player_id} } # originating player's id
sub desc {
    my $action = shift;
    my $desc = '';
    $desc .= "<i>" . $action->player_id . "</i> ";
    if($action->type == 1) {
        $desc .= "moved the " . $action->card->id . " card"; #  to position (", $action->card->x, ', ', $action->card->y, ")"); # no, we don't know what position it was moved to, only where it's at now
    } elsif($action->type == 2) {
        # $request->print("rotated the ", $action->card->id, " card"); # not really even interesting enough to log
    } elsif($action->type == 3) {
        $desc .= "flipped over the " . $action->card->id . " card";
    } elsif($action->type == 4) {
        $desc .= "peeked at the " . $action->card->id . " card";
    } elsif($action->type == 5) {
        $desc .= "rolled a " . $action->text;
    }
    if($action->text) {
        $desc .= '; ' if $desc;
        $desc .= $action->text;
    }
    return $desc;
}

package player;

sub new { my $pack = shift; bless { @_ }, $pack; }
sub player_id :lvalue { $_[0]->{player_id} }
sub password :lvalue { $_[0]->{password} }

package card;

sub new { my $pack = shift; bless { @_ }, $pack; }
sub x :lvalue { $_[0]->{x} } 
sub y :lvalue { $_[0]->{y} } 
sub z :lvalue { $_[0]->{z} } 
sub card_x :lvalue { $_[0]->{card_x} }  # width
sub card_y :lvalue { $_[0]->{card_y} }  # height
sub hid :lvalue { $_[0]->{hid} } 
sub id :lvalue { $_[0]->{id} }
sub image { $_[0]->hid ? $_[0]->{back_img} : $_[0]->{front_img} }
sub front_img :lvalue { $_[0]->{front_img} }
sub back_img :lvalue { $_[0]->{back_img} }

package dice;
use base 'card';

sub new { my $package = shift; my $self = $package->SUPER::new(@_); $self->do_roll; $self; }
sub roll :lvalue { $_[0]->{roll} }  
sub do_roll :lvalue { $_[0]->roll = 1 + int rand 6; $_[0]->roll }  
sub image { '/jpg/d' . $_[0]->roll . '.gif'; }
sub front_image { $_[0]->image }
sub back_image { $_[0]->image }

__END__

Primarily will do two things:

* Accept movement infomation (card id whatever moved to position, or card id whatever was hidden or revealed)
* Display movement information (get a generation number, send JavaScript updaters for all movements that have passed since along with a new generation number)

Movement JavaScript snippets can include:

* Reveal card
* Rotate card
* Move card

Since we're just logging the card affected and a text comment, might be updating all of these.

Todo:

* Generic card loader that takes a simple file format that lets cards be arranged in one or more piles, 
  perhaps organized by type, some delt to start with, some face down, some face up, etc.
* On card movement requests, scan the action log to see if that same card has been diddled by
  someone else in the mean time, and if so, deny the request with the appropriate message -- 
  the user probably didn't want to move the card if someone else already did.
* Perhaps allow text to be applied to cards later so we can scale them down small but have an alt tag 
  people can hoover for and get.
* Multiple independant games
* Serializing out game state
* Should increase the z-index of whatever card I most recently touched
* Money counters/cards of different sizes when loading from config
* Keep a transaction log and let people scroll through it
* Allow users to upload card images as well as a background to use as an optional game board
* Dice
* New game creation options/game config: include turnover pad, include reveal pad, include rotate pad,
  background
* Ability to download and upload serialized games as a cheapo save/restore feature
  
Continuity
----------
* Perhaps redefine 'print' in the importer's package... but then how to refer to $request?
* Shouldn't die unless things are very seriously wrong -- that'll take out the whole app.  Log it and sally forth.
* More of a message passing backend -- at least examples of using Event to watch variables, creating queues, etc.
* DBI wrapping for multiplexing
* send_static needs to use the io 'w' event too to avoid overflowing the buffer.

..........

        <script language="javascript">
           if(top.good.location.href != "$url") top.good.location.href="$url";
       </script>
for i in *;do djpeg $i | pnmscale 0.5 | cjpeg > "jpg/$i";done
