use Terminal::MultiProgress;

my $events = supply {
   emit %( :id<hare>, :status<start>, timestamp => now );
   sleep 2;
   emit %( :id<hare>, :status<finish>, timestamp => now );
}

Terminal::MultiProgress.new(:!show-summary, :show-title, :show-frame, title => 'runners').run: $events;
