#!/bin/sh
# Slowly emit "id status" lines and pipe them into pipe.raku for a progress display.
raku -e '$*OUT.out-buffer = 0; for 1..5 -> $i { sleep 1; put "job$i start" }; for 1..5 -> $i { sleep 1; put "job$i finish" }' \
  | raku -Ilib eg/pipe.raku
