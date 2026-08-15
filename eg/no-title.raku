use Terminal::MultiProgress;

my $events = supply {
   emit %( :id<hare>, :status<start>, timestamp => now );
   sleep 2;
   emit %( :id<hare>, :status<finish>, timestamp => now );
}

Terminal::MultiProgress.new(:!show-title, :show-frame, :show-summary).run: $events;
