unit class Terminal::MultiProgress::Event;

enum Status <Started Finished>;

has DateTime $.timestamp is required;
has Str $.identifier is required;
has Status $.status is required;

multi method create(Hash $in) {
  self.new:
     timestamp  => ($in<timestamp>.?DateTime // DateTime.now),
     identifier => ($in<identifier> // $in<id> // die "no id for event"),
     status     =>   $in<status>.fc.contains('start')        ?? Started
                  !! $in<status>.fc.contains('finish'|'end') ?? Finished
                  !! die "unknown status " ~ $in<status>;
}
