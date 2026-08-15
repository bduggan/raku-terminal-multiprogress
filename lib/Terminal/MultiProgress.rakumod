use Terminal::ANSI::OO :t;
use Terminal::ANSI;
use Log::Async;

logger.untapped-ok = True;
logger.send-to: '/tmp/debug.log' if $*ENV<TMPROG_DEBUG>;

unit class Terminal::MultiProgress;
use Terminal::MultiProgress::Event;
use Terminal::MultiProgress::Update;
constant Event = Terminal::MultiProgress::Event;
constant Update = Terminal::MultiProgress::Update;

has Str  $.title     = 'progress';
has Int  $.rule-width  = 40;
has Real $.tick    = 1;
has Str  $.running-color  = '#aabbaa';
has Str  $.finished-color = '#339933';
has Bool $.trap-sigint = True;
has Bool $.full-screen = False;
has Bool $.show-title  = False;
has Bool $.show-frame  = False;
has Bool $.show-summary = False;
has Int  $.max-rows;             # at most this many entries on screen at once
has Bool $.clear-finished = False;   # finished entries leave the display
has Sub  $.summary-line = sub (:$completed, :$running, :$visible, :$tick) {
  my $vis = $visible == $running ?? "" !! " (visible: $visible)";
  t.bold, "($tick) completed: $completed", t.text-reset,
  "   running: $running$vis", t.erase-to-end-of-line;
}

# Given a Terminal::MultiProgress::Update, return the line to draw for that
# id.  Called on every event and on every tick; see !default-update.
has &.update;

has Int $!top;
has Int $!height;
has     $!bottom;   # last entry row, or Inf when we can just keep growing
has Int $!col = 1;
has Int $!lines;    # terminal height
has Int $!nlines;   # lines we own, below the cursor's starting line (non-full-screen)

has %!row-of;    # id -> screen row
has %!start-ts;  # id -> log start timestamp (epoch secs); the elapsed anchor
has %!done;      # id -> elapsed seconds (once finished)
has %!last;      # id -> the line we drew for it last
has Int $!next-row;
has Int $!completed = 0;

# the rows below the last entry: they move down as entries are added
method !rule-row    { $!full-screen ?? $!bottom + 1 !! $!next-row }
method !summary-row { self!rule-row + ($!show-frame ?? 1 !! 0) }

# how many rows our block occupies, given the entries placed so far
method !rows-needed {
  ($!top - 1, $!next-row - 1,
   ($!show-frame   ?? self!rule-row    !! 0),
   ($!show-summary ?? self!summary-row !! 0)).max;
}

# make sure our block has $n lines; the cursor stays on the last one
method !claim(Int $n) {
  return if $n <= $!nlines;
  print "\n" x ($n - $!nlines), t.start-of-line;
  $!nlines = $n;
}

# print at a row (absolute when full-screen, otherwise relative to our block)
method !put(Int $row, *@parts) {
  atomically {
    if $!full-screen {
      print t.print-at($row, $!col, ''), |@parts;
    } else {
      my $up = $!nlines - $row;
      return if $up >= $!lines;  # scrolled off the top
      print ($up ?? t.cursor-up($up) !! ''), t.start-of-line,
        ($!col > 1 ?? t.cursor-right($!col - 1) !! ''),
        |@parts,
        t.start-of-line, ($up ?? t.cursor-down($up) !! '');
    }
  }
}

# what we draw when no update callback was given
method !default-update(Update $u) {
  ($u.finished ?? t.color($!finished-color) !! t.color($!running-color))
  ~ ($u.finished ?? "{$u.id}  started ... finished in {$u.timer}"
                 !! "{$u.id}  started ... (elapsed {$u.timer})")
  ~ t.text-reset;
}

method !redraw($id) {
  my $row = %!row-of{$id} or return;
  my $fin = %!done{$id}:exists;
  my $u = Update.new:
    id       => $id,
    elapsed  => (($fin ?? %!done{$id} !! now.to-posix[0] - %!start-ts{$id}) max 0),
    finished => $fin,
    last     => (%!last{$id} // '');
  my $line = ((&!update ?? &!update($u) !! self!default-update($u)) // '').Str;
  %!last{$id} = $line;
  self!put: $row, $line, t.erase-to-end-of-line;
}

method !draw-summary() {
  return unless $!show-summary;
  state $tick = 0;
  my $running = %!start-ts.keys.grep({ %!done{$_}:!exists }).elems;
  my $visible = %!row-of.keys.grep({ %!done{$_}:!exists }).elems;
  self!put: self!summary-row, self.summary-line.(
    :$!completed, :$running, :$visible, :$tick
  );
  $tick++;
}

method !draw-frame() {
  self!put: 1, t.bold, $!title, t.text-reset, t.erase-to-end-of-line if $!show-title;
  return unless $!show-frame;
  self!put: $!top - 1, "━" x $!rule-width, t.erase-to-end-of-line;
  self!put: self!rule-row, "━" x $!rule-width, t.erase-to-end-of-line;
}

# the window is full: everything moves up a line, the top entry falls off, and
# $id takes the bottom row.  The rows below the entries never move.
method !slide-up($id) {
  my $last-row = $!next-row - 1;
  if $!full-screen {
    print t.set-scroll-region($!top, $last-row)
      ~ t.scroll-up
      ~ t.reset-scroll-region;
    $*OUT.flush;
  }
  for %!row-of.keys.grep({ %!row-of{$_} == $!top }) {
    %!row-of{$_}:delete;
    %!last{$_}:delete;
  }
  %!row-of{$_}-- for %!row-of.keys;
  %!row-of{$id} = $last-row;
  unless $!full-screen {   # the scroll region did the moving for us
    self!redraw($_) for %!row-of.keys.grep(* ne $id);
  }
}

# take an entry off the display: the ones under it move up to close the gap, so
# the list stays packed at the top and the blank lines are at its bottom.  The
# entries above it -- the long running ones -- never move.
method !drop($id) {
  my $row  = %!row-of{$id}:delete // return;
  my $last = (%!row-of.values, $row).flat.max;   # this one goes blank
  %!last{$id}:delete;
  my @below = %!row-of.keys.grep({ %!row-of{$_} > $row });
  %!row-of{$_}-- for @below;
  atomically {
    self!put: $last, t.erase-to-end-of-line;
    self!redraw($_) for @below;
  }
}

method !place($id) {
  # assign a row: reuse a blank one, then grow, then scroll
  return %!row-of{$id} if %!row-of{$id}:exists;
  atomically {
    my $taken = %!row-of.values.Set;
    my $free  = ($!top ..^ $!next-row).first({ !$taken{$_} });
    if $free.defined {
      %!row-of{$id} = $free;
    } elsif $!next-row <= $!bottom {
      %!row-of{$id} = $!next-row++;
      unless $!full-screen {       # one more line of our own
        self!claim(self!rows-needed);
        self!draw-frame;
      }
    } else {
      self!slide-up($id);          # full: the top entry scrolls off
    }
  }
  %!row-of{$id};
}

method !record($ev) {
  return unless $ev;
  my $id  = $ev.identifier;
  my Terminal::MultiProgress::Event::Status $status = $ev.status;
  my $ts  = $ev.timestamp.posix + $ev.timestamp.second % 1;  # keep the fraction
  given $status {
    when Terminal::MultiProgress::Event::Status::Started {
      %!start-ts{$id} //= $ts;
      self!place($id);
    }
    when Terminal::MultiProgress::Event::Status::Finished {
      %!start-ts{$id} //= $ts;  # in case we missed the start
      self!place($id) unless $!clear-finished;
      $!completed++ unless %!done{$id}:exists;
      %!done{$id} = ($ts - %!start-ts{$id}) max 0;
      self!drop($id) if $!clear-finished;
    }
    default { return }
  }
  self!redraw($id);
  self!draw-summary;
}

method run(Supply $events) {
  debug "starting run";
  # rows above the entries: an optional title, then an optional rule
  $!top      = 1 + ($!show-title ?? 1 !! 0) + ($!show-frame ?? 1 !! 0);
  $!lines    = qx[tput lines].Int || 24;  # fall back when tput has no terminal to query (e.g. no $TERM)
  # full-screen fills the terminal; otherwise we only stop growing if asked to
  my $rows   = $!full-screen
    ?? (($!lines - $!top - ($!show-frame ?? 1 !! 0) - ($!show-summary ?? 1 !! 0)) max 5)
    !! Inf;
  $rows      = $!max-rows if $!max-rows.defined && $!max-rows < $rows;
  $!bottom   = $rows == Inf ?? Inf !! $!top + $rows - 1;
  $!next-row = $!top;
  $!nlines   = 1;   # the line the cursor is on is the top of our block

  $*OUT.out-buffer = 0;
  if $!full-screen {
    print t.save-screen ~ t.hide-cursor ~ t.clear-screen ~ t.home;
  } else {
    # claim the lines we need here; the rest come one at a time
    print t.hide-cursor, t.start-of-line;
    self!claim(self!rows-needed);
  }
  self!draw-frame;
  self!draw-summary;

  # We need to start another thread explicitly when there are multiple whenevers
  # in a react.
  my $chan = Channel.new;
  start {
    $events.tap:
      { $chan.send($_) },
      done => { $chan.close },
      quit => { $chan.fail($_) }
  }

  react {
    debug "starting react loop";
    whenever $chan -> $ev {
      debug "got event " ~ $ev.raku;
      if $ev ~~ Event {
        self!record: $ev;
      } else {
        self!record: Event.create: $ev;
      }
      LAST { done }
    }
    whenever Supply.interval($!tick) {
      self!redraw($_) for %!row-of.keys.grep({ %!done{$_}:!exists });
      self!draw-summary;
    }
    if $!trap-sigint {
      whenever signal(SIGINT) { done }
    }
  }

  print t.show-cursor;
  print $!full-screen ?? t.restore-screen !! "\n";  # leave the cursor below our block
  $*OUT.flush;
}

=begin pod

=head1 NAME

Terminal::MultiProgress -- Report progress on multiple things at once in your terminal

=head1 SYNOPSIS

=begin code :lang<raku>
use Terminal::MultiProgress;

# make a new widget, see below for options
my $prog = Terminal::MultiProgress.new: title => 'race';

# events can be hashes or objects, with optional timestamps
my $events = supply {
   emit %( :id<hare>,     :status<started> );
   emit %( :id<tortoise>, :status<started> );
   sleep 2;
   emit %( :id<hare>,     :status<finished> );
   sleep 1;
   emit %( :id<tortoise>, :status<finished> );
}

# Use run to send the output to the terminal (blocks until it finishes)
$prog.run: $events

=end code

Output will be status lines that are updated as time
goes by.  Updates happen every second, starting with

=begin output

hare  started ... (elapsed 00:00:00)
tortoise  started ... (elapsed 00:00:00)

=end output

and ending with 

=begin output

hare  started ... finished in 00:00:02
tortoise  started ... finished in 00:00:03

=end output

See below for how to control the output format, and for more
interesting examples.  Or download the examples in L<eg/> and
run them, e.g. who will win this one?

=begin output

$ raku eg/race.raku

hare vs tortoise
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌🐇··································🏁
╌╌╌╌╌🐢·············································🏁
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
slow and steady

=end output

=head1 DESCRIPTION

This module is for generating multiple progress bars on your
screen for a collection of asynchronous events.  It provides
an interface for configuring the look and feel of the output
and then receives a Supply of events.  Each event needs an
an identifier which is used to find the right row to update.
Scrolling and reaping completed events is handled properly.
There is also an C<update> option for managing updates -- this
receives a object with enough context to generate a status
line that will be updated in place for that identifier.

=head1 ATTRIBUTES

=item C<title> -- heading shown when C<show-title> is set

=item C<rule-width> -- width in columns of the C<show-frame> rule lines

=item C<tick> -- seconds between redraws of running entries

=item C<running-color> -- default text color for entries that are still running

=item C<finished-color> -- default text color for entries that have finished

=item C<trap-sigint> -- stop C<run> cleanly on SIGINT

=item C<full-screen> -- take over the whole terminal instead of drawing below the cursor

=item C<show-title> -- draw the C<title> above the entries

=item C<show-frame> -- draw a rule above and below the entries

=item C<show-summary> -- draw a completed/running count below the entries

=item C<max-rows> -- cap on visible entries; older ones scroll off when exceeded

=item C<clear-finished> -- remove an entry's row once it finishes, closing the gap

=item C<summary-line> -- C<sub (:$completed, :$running, :$visible, :$tick)> returning the text for the summary row

=item C<update> -- C<sub (Terminal::MultiProgress::Update)> returning the text for an entry's row.  See UPDATES below.

=head1 METHODS

=item C<new> -- construct a widget; takes the attributes above as named arguments

=item C<run(Supply $events)> -- consume events and draw until the supply is done.  See below
for the format of events.

=head1 EVENTS

Events that are sent to C<run> can be either a hash or a C<Terminal::MultiProgress::Event> object.

The object has C<timestamp> (DateTime), C<identifier> (Str) and C<status> (Status enum) attributes.
The status enum is either Started or Finished.

The hash can contain these keys which will autocreate an object.

  * id/identifier -- the id for the event update
  * timestamp -- when it was updated (default now)
  * status -- a string containing start or finish/end

=head1 UPDATES

The update callback receives a C<Terminal::MultiProgress::Update> object which has
an C<id>, C<elapsed> time (seconds), C<finished> for whether the status is finished,
and C<last> which is the last line that was drawn for this item.

=head1 EXAMPLES

See the C<eg/> directory for examples.

=head1 AUTHOR

Brian Duggan

=end pod


