unit class Terminal::MultiProgress::Update;

#| What an update callback is handed: everything known about one identifier
#| at the moment its line is (re)drawn -- on an event, or on every tick.

has Str  $.id       is required;
has Real $.elapsed  = 0;      # seconds since this id started
has Bool $.finished = False;
has Str  $.last     = '';     # the line we drew for this id last time

#| Elapsed time as hh:mm:ss.
method timer {
  $!elapsed.Int.polymod(60, 60).reverse.list.fmt('%02d', ':');
}
