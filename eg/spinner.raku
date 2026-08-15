use Terminal::MultiProgress;
use Terminal::ANSI::OO :t;

# 50 dependencies, 6 lines of screen: finished ones disappear.

constant @dots = <⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏>;

my @deps = <
  left-pad right-pad middle-pad any-pad no-pad double-pad
  is-odd is-even is-odd-ish indent dedent undent unindent has-value has-values
  kind-of type-of-type to-regex-range regex-not-regex chalk-dust ansi-lite
  tiny-lru object-assign-ponyfill array-flatten-2 flatten-flatter is-array-array
  deep-equal-ish shallow-clone-lite micro-merge merge-deeper path-join-safe
  safe-buffer-safer buffer-from-from trim-left-now trim-right-now camelize
  decamelize snake-to-kebab kebab-to-snake snake-to-mouse camel-to-snake
  decamel-to-mouse camel-to-snake-kebab uuid-ish nano-nano-id macro-id debounce
  throttle-debounce once-only-once memoize-maybe promisify-everything sleep-ms
  sleep-ns sleep-hours sleep-days sleep-years sleep-eternity wait-a-tick
  is-promise-like emitter-3000 tiny-glob-glob glob-parent-parent
  minimatch-mini semver-ish resolve-from-where find-up-down read-pkg-up-up
>;

my %secs = @deps.kv.map: -> $i, $id { $id => ($i %% 7 ?? (20 .. 40).pick !! (5..10).pick) };
my $wide = @deps>>.chars.max;

my $n = 0;
my &spin = -> $u {
  $n++;
  my $slow = $u.elapsed > 8;
  my $pct  = (100 * $u.elapsed / %secs{$u.id}).Int min 100;
  t.color($slow ?? '#ccaa44' !! '#8899cc')
    ~ @dots[(($u.elapsed / .1).Int + $n)  % @dots] ~ ' ' ~ $u.timer ~ t.text-reset
    ~ " {$u.id.fmt("%-{$wide}s")}"
    ~ ($slow ?? ' ' ~ ('=' x ($pct / 5).Int) ~ "[$pct%]" !! '');
}

my @free = .5 xx 8;                 # when each of the eight slots frees up
my @plan;                           # [when, id, status]
for @deps -> $id {
  my $w = @free.minpairs[0].key;
  @plan.push: [ @free[$w] + .05, $id, 'start' ];   # just after the slot frees up
  @free[$w] += %secs{$id};
  @plan.push: [ @free[$w], $id, 'finish' ];
}

# start run() needs to tap us)
my $events = Supplier.new;
for @plan -> [$at, $id, $status] {
  Promise.in($at).then: { $events.emit: %( :$id, :$status, timestamp => now ) }
}
Promise.in(@free.max + .5).then: { $events.done }

Terminal::MultiProgress.new(
  title => "installing {+@deps} packages",
  :!show-frame, :show-title, :show-summary, :clear-finished,
  max-rows => 8, tick => .1, update => &spin,
).run: $events.Supply;
