
all:
	zig build

test:
	zig build test

watch:
	ag -l | entr -s "make test"

run:
	xinit ./xinitrc -- /usr/bin/Xephyr :30 -ac -screen 800x600 -host-cursor -reset +xinerama

run2:
	xinit ./xinitrc -- /usr/bin/Xephyr :30 -ac -screen 800x600 -screen 600x300 -host-cursor -reset +xinerama


.PHONY: test



