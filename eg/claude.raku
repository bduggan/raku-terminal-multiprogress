use Terminal::MultiProgress;
use Terminal::ANSI::OO :t;

# Riffing on Claude Code's own spinner: a rotating asterisk, a whimsical
# gerund, and a running token count -- one line per subagent.

constant @glyphs = <✢ ✳ ✻ ✽ ∗ ✦>;

constant @words = <
  Accomplishing Actualizing Cogitating Combobulating Contemplating Divining
  Frolicking Germinating Herding Ideating Jitterbugging Marinating Meandering
  Mulling Noodling Percolating Perusing Philosophising Pondering Pontificating
  Puttering Puzzling Reticulating Ruminating Schlepping Shimmying Spelunking
  Synthesizing Unfurling Vibing Wibbling Wrangling Zooming
>;

# 1m 27s rather than 00:01:27
sub mmss($elapsed) {
  my $s = $elapsed.Int;
  $s < 60 ?? "{$s}s" !! "{($s / 60).Int}m {$s % 60}s";
}

my @agents = <Explore general-purpose code-reviewer Plan claude-code-guide>;
my %word   = @agents.map: { $_ => @words.pick };
my %rate   = @agents.map: { $_ => (60..220).pick };  # tokens/sec, some agents ramble
my %color  = Explore             => '#61afef',
             'general-purpose'   => '#c678dd',
             'code-reviewer'     => '#e5c07b',
             Plan                => '#98c379',
             'claude-code-guide' => '#e06c75';

my &spin = -> $u {
  my $w      = %word{$u.id};
  my $tokens = (%rate{$u.id} * $u.elapsed).Int;
  my $glyph  = @glyphs[($u.elapsed / .12).Int % @glyphs.elems];
  t.color(%color{$u.id}) ~ (
    $u.finished
      ?? "✓ $w… done  ({mmss $u.elapsed} · {$u.id} · $tokens tokens)"
      !! "$glyph $w…  (esc to interrupt · {mmss $u.elapsed} · ↑ $tokens tokens · {$u.id})"
  ) ~ t.text-reset;
}

my @plan;
my $max-finish = 0;
for @agents -> $id {
  my $start = (0.2 .. 1.5).pick;
  my $dur   = (2 .. 90).pick;   # long enough to see the "1m 27s" style timer kick in
  @plan.push: [ $start, $id, 'start' ];
  @plan.push: [ $start + $dur, $id, 'finish' ];
  $max-finish max= $start + $dur;
}

my $events = Supplier.new;
for @plan -> [$at, $id, $status] {
  Promise.in($at).then: { $events.emit: %( :$id, :$status, timestamp => now ) }
}
Promise.in($max-finish + .5).then: { $events.done }

Terminal::MultiProgress.new(
  title        => 'spawning subagents',
  :show-title, :show-frame, :show-summary,
  tick         => .1,
  update       => &spin,
  summary-line => sub (:$completed, :$running, :$visible, :$tick) {
    $running == 0 ?? 'all subagents reporting back' !! "$running still cooking, $completed done"
  },
).run: $events.Supply;
