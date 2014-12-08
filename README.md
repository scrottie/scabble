This thing is quite antique now.  I created it to play Steve Jackson
Games' Illuminati online with friends, but then later changed it
to play Scrabble.  It's been getting a fair bit of use among friends
lately, which means new features, so that nominated it for going in 
to git.

It's based on the Perl Continuity framework.  Each player gets real-time
updates from the server whenever any other player moves anything, rolls
dice, or turns any cards over.

The server doesn't know anything about any game rules.  It only
understands 6 sided dice that change to a random face when moved,
turning over cards, and moving things.  Game state is propogated to
all viewers.

The unrealized intention was to have it read an XML file or whatever
(XML was still cool at that time) and take the specification of
how to do the initial layout with respect to shuffling decks,
and positioning them and other game pieces on the board.  This is
the bit that's currently hard-coded for Scrabble.

Scrabble is a trademark of Hasbro or J.W. Spear & Sons Limited,
depending on where you are.  I'm figuring the included game board
imagine is in violation of trademarks and copyrights but not the
code as it really, really does not have any knowledge built in
about game play of that or any other game and is just a message
backend.
