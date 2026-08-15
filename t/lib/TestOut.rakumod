unit module TestOut;

#| Run &code with $*OUT.print wrapped to collect (and swallow) everything
#| printed; return it with the ANSI escapes stripped, or Nil on timeout.
sub capture-run(&code, :$timeout = 10) is export {
  my $text = '';
  my $print = $*OUT.^find_method('print');
  my $wrapped = $print.wrap: method (|c) { $text ~= c.list.join }
  my $done = start code();
  await Promise.anyof($done, Promise.in($timeout));
  $print.unwrap($wrapped);
  return Nil if $done.status ~~ Planned;
  await $done;   # rethrow if &code died
  $text.subst(/\e '[' <[0..9;?]>* <[a..zA..Z]>/, '', :g);
}
