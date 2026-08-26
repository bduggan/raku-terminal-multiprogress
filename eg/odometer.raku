use Terminal::MultiProgress;

# Exercises the default odometer renderer (dots -> ▁ -> █, "done" column
# alignment). speed scales up elapsed time so the carry/freeze stages show
# up well within the sleeps below, instead of taking as many real seconds
# as there are terminal columns.

my $events = supply {
   emit %( :id<a>, :status<start> );
   sleep 1;
   emit %( :id<b>, :status<start> );
   sleep 1;
   emit %( :id<c>, :status<start> );
   sleep 3;
   emit %( :id<a>, :status<finish> );
   sleep 10;
   emit %( :id<b>, :status<finish> );
   sleep 15;
   emit %( :id<c>, :status<finish> );
}

Terminal::MultiProgress.new(tick => 0.1, speed => 200).run: $events;
