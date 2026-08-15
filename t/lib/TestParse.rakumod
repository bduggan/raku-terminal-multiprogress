unit module TestParse;

use Terminal::MultiProgress::Event;

sub parse-line(Str $line) is export {
  $line ~~ /^ :s [ (\S+) ]? (\S+) ( start | finish ) $/ or return Nil;
  my $ts = (try DateTime.new(~($0 // ''))) // DateTime.now;
  Terminal::MultiProgress::Event.new(
    timestamp  => $ts,
    identifier => ~$1,
    status     => ~$2 eq 'start'
      ?? Terminal::MultiProgress::Event::Status::Started
      !! Terminal::MultiProgress::Event::Status::Finished,
  );
}
