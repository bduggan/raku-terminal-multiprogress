use Terminal::MultiProgress;

my $events = supply {
   emit %( :id<hare>,     :status<start> );
   emit %( :id<tortoise>, :status<start> );
   sleep 5;
   emit %( :id<hare>,     :status<finish> );
   sleep 10;
   emit %( :id<tortoise>, :status<finish> );
}

Terminal::MultiProgress.new.run: $events;
