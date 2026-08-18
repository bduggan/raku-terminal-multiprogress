#!/usr/bin/env raku
# Read "id status" lines from stdin and show progress.  See eg/cli.sh to run it.

use Terminal::MultiProgress;

my $events = supply {
  for $*IN.lines -> $line {
    my ($id, $status) = $line.words;
    emit %( :$id, :$status );
  }
}

Terminal::MultiProgress.new.run: $events;
