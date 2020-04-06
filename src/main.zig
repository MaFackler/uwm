const c = @import("c.zig");
const std = @import("std");
const warn = std.debug.warn;
const panic = std.debug.panic;

var display: ?*c.Display = undefined;
var window: c.Window = undefined;
var root: c.Window = undefined;

pub fn main() void {
    display = c.XOpenDisplay(null) orelse {
        panic("unable to create window");
    };

    defer {
        _ = c.XCloseDisplay(display);
    }

    var screen: i32 = 0;
    screen = c.XDefaultScreen(display);
    var bp: c_ulong = c.XBlackPixel(display, screen);
    var wp: c_ulong = c.XWhitePixel(display, screen);
    root = c.XRootWindow(display, screen);

    window = c.XCreateSimpleWindow(display, root, 10, 10, 100, 100, 1, bp, wp);

    _ = c.XSelectInput(display, window, c.ExposureMask | c.KeyPressMask);
    _ = c.XMapWindow(display, window);

    var e: c.XEvent = undefined;
    while (true) {
        _ = c.XNextEvent(display, &e);

        if (e.type == c.Expose) {
            warn("Expose");
            _ = c.XFillRectangle(display, window, c.XDefaultGC(display, screen), 20, 20, 100, 100);
        }
        if (e.type == c.KeyPress) {
            break;
        }
    }
}
