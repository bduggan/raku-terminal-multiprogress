[![Actions Status](https://github.com/bduggan/raku-terminal-multiprogress/actions/workflows/linux.yml/badge.svg)](https://github.com/bduggan/raku-terminal-multiprogress/actions/workflows/linux.yml)
[![Actions Status](https://github.com/bduggan/raku-terminal-multiprogress/actions/workflows/macos.yml/badge.svg)](https://github.com/bduggan/raku-terminal-multiprogress/actions/workflows/macos.yml)

NAME
====

Terminal::MultiProgress -- Report progress on multiple things at once in your terminal

SYNOPSIS
========

```raku
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
```

Output will be status lines that are updated as time goes by. Updates happen every second, starting with

    hare  started ... (elapsed 00:00:00)
    tortoise  started ... (elapsed 00:00:00)

and ending with 

    hare  started ... finished in 00:00:02
    tortoise  started ... finished in 00:00:03

See below for how to control the output format, and for more interesting examples. Or download the examples in [eg/](eg/) and run them, e.g. who will win this one?

    $ raku eg/race.raku

    hare vs tortoise
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    --------------🐇....................................🏁
    -----🐢.............................................🏁
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    slow and steady

DESCRIPTION
===========

This module is for generating multiple progress bars on your screen for a collection of asynchronous events. It provides an interface for configuring the look and feel of the output and then receives a Supply of events. Each event needs an an identifier which is used to find the right row to update. Scrolling and reaping completed events is handled properly. There is also an `update` option for managing updates -- this receives a object with enough context to generate a status line that will be updated in place for that identifier.

ATTRIBUTES
==========

  * `title` -- heading shown when `show-title` is set

  * `rule-width` -- width in columns of the `show-frame` rule lines

  * `tick` -- seconds between redraws of running entries

  * `running-color` -- default text color for entries that are still running

  * `finished-color` -- default text color for entries that have finished

  * `trap-sigint` -- stop `run` cleanly on SIGINT

  * `full-screen` -- take over the whole terminal instead of drawing below the cursor

  * `show-title` -- draw the `title` above the entries

  * `show-frame` -- draw a rule above and below the entries

  * `show-summary` -- draw a completed/running count below the entries

  * `max-rows` -- cap on visible entries; older ones scroll off when exceeded

  * `clear-finished` -- remove an entry's row once it finishes, closing the gap

  * `summary-line` -- `sub (:$completed, :$running, :$visible, :$tick)` returning the text for the summary row

  * `update` -- `sub (Terminal::MultiProgress::Update)` returning the text for an entry's row. See UPDATES below.

METHODS
=======

  * `new` -- construct a widget; takes the attributes above as named arguments

  * `run(Supply $events)` -- consume events and draw until the supply is done. See below for the format of events.

EVENTS
======

Events that are sent to `run` can be either a hash or a `Terminal::MultiProgress::Event` object.

The object has `timestamp` (DateTime), `identifier` (Str) and `status` (Status enum) attributes. The status enum is either Started or Finished.

The hash can contain these keys which will autocreate an object.

    * id/identifier -- the id for the event update
    * timestamp -- when it was updated (default now)
    * status -- a string containing start or finish/end

UPDATES
=======

The update callback receives a `Terminal::MultiProgress::Update` object which has an `id`, `elapsed` time (seconds), `finished` for whether the status is finished, and `last` which is the last line that was drawn for this item.

EXAMPLES
========

See the `eg/` directory for examples.

AUTHOR
======

Brian Duggan

