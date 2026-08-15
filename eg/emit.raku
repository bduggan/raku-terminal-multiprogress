use Terminal::MultiProgress;
use Terminal::MultiProgress::Event;

my $prog = Terminal::MultiProgress.new: title => 'runners', :show-title, :show-frame, :show-summary;

my $events = supply {
   emit %( :id<hare>,     :status<start>, timestamp => now );
   emit %( :id<tortoise>, :status<start>, timestamp => now );
   sleep 2;
   emit %( :id<hare>,     :status<finish>, timestamp => now );
   sleep 3;
   emit %( :id<tortoise>, :status<finish>, timestamp => now );
   sleep 10;
}

# works fine
#react whenever $events {
#  say .raku;
#}
$prog.run: $events;


