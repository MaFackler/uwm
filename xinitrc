APP=xterm
export DISPLAY=:30
sleep 1 && $APP &
sleep 2 && $APP &
sleep 3 && $APP &
sleep 4 && $APP &
exec ./zig-cache/bin/uwm
