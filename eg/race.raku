use Terminal::MultiProgress;
use Terminal::ANSI::OO :t;

# The update callback owns the line: here it turns elapsed time into distance.

constant TRACK = 50;
my %icon  = hare => '🐇', tortoise => '🐢';
my %color = hare => '#dd8855', tortoise => '#66aa66';

# columns covered by $id after $t seconds -- the hare naps from 2s to 8s
sub distance($id, $t) {
  my $d = $id eq 'hare'
    ?? ($t < 2 ?? $t * 20 !! 40 + (($t - 8) max 0) * 20)
    !! $t * 7;
  ($d.Int, TRACK).min;
}

my &race = -> $u {
  my $d = $u.finished ?? TRACK !! distance($u.id, $u.elapsed);
  t.color(%color{$u.id})
    ~ ('-' x $d) ~ %icon{$u.id} ~ ('.' x (TRACK - $d)) ~ '🏁'
    ~ ($u.finished ?? "  {$u.timer}" !! '')
    ~ t.text-reset;
}

my $events = supply {
  emit %( :id<hare>,     :status<start>, timestamp => now );
  emit %( :id<tortoise>, :status<start>, timestamp => now );
  sleep 8;
  emit %( :id<tortoise>, :status<finish>, timestamp => now );
  sleep 1;
  emit %( :id<hare>,     :status<finish>, timestamp => now );
}

Terminal::MultiProgress.new(
  title      => 'hare vs tortoise',
  rule-width => TRACK + 4,
  tick       => 0.1,
  update     => &race,
  :show-title, :!show-frame, :show-summary,
  summary-line => sub (:$completed, :$running, :$visible, :$tick) {
    $completed == 0 ?? "slow and steady" !! "wins the race   "
  }

).run: $events;
