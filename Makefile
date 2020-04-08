
all:
	zig build

test:
	zig build test

run:
	xinit ./xinitrc -- /usr/bin/Xephyr :30 -ac -screen 800x600 -host-cursor -reset +xinerama

run2:
	xinit ./xinitrc -- /usr/bin/Xephyr :30 -ac -screen 800x600 -screen 800x600 -host-cursor -reset +xinerama


.PHONY: test



