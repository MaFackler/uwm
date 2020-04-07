APP=xterm
export DISPLAY=:30
sleep 1 && $APP &
sleep 2 && $APP &
sleep 3 && $APP &
sleep 4 && $APP &
sleep 5 && rofi -show run &
exec ./zig-cache/bin/uwm
