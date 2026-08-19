use Terminal::MultiProgress;

my $events = supply {
   emit %( :id<hare>,     :status<start> );
   emit %( :id<tortoise>, :status<start> );
   sleep 10;
   emit %( :id<hare>,     :status<finish> );
   sleep 20;
   emit %( :id<tortoise>, :status<finish> );
}

Terminal::MultiProgress.new(tick => 0.1).run: $events;
