const std = @import("std");
const c = @import("c.zig");
const panic = std.debug.panic;

pub const Xlib = struct {
    display: *c.Display = undefined,
    screen: i32 = 0,
    root: c.Window = undefined,
    colormap: c.Colormap = undefined,
    // TODO: maybe dynamic array to support more than 16 colors
    colors: [16]u64 = undefined,

    const Self = *Xlib;
    fn init(self: Self) void {
        self.display = c.XOpenDisplay(null) orelse {
            panic("unable to create window");
        };
        self.screen = c.XDefaultScreen(self.display);
        self.root = c.XRootWindow(self.display, self.screen);
        self.colormap = c.XDefaultColormap(self.display, self.screen);

        var windowAttributes: c.XSetWindowAttributes = undefined;
        windowAttributes.event_mask = c.SubstructureNotifyMask | c.SubstructureRedirectMask | c.KeyPressMask | c.EnterWindowMask | c.FocusChangeMask | c.PropertyChangeMask;
        _ = c.XSelectInput(self.display, self.root, windowAttributes.event_mask);
        _ = c.XSync(self.display, 0);
    }

    fn delete(self: Self) void {
        _ = c.XCloseDisplay(self.display);
    }

    fn getDisplayWidth(self: Self) u32 {
        displayWidth = @intCast(u32, c.XDisplayWidth(display, xscreen));
    }

    fn getDisplayHeight(self: Self) u32 {
        displayHeight = @intCast(u32, c.XDisplayHeight(display, xscreen));
    }

    fn grabKey(self: Self, mask: u32, key: u32) void {
        var code = c.XKeysymToKeycode(self.display, key);
        _ = c.XGrabKey(self.display, code, mask, self.root, 1, c.GrabModeAsync, c.GrabModeAsync);
    }

    fn closeWindow(self: Self, window: c.Window) void {
        _ = c.XKillClient(self.display, window);
    }

    fn addColor(self: Self, index: usize, r: u8, g: u8, b: u8) void {
        var xColor: c.XColor = undefined;
        xColor.red = @intCast(u16, r) * 255;
        xColor.green = @intCast(u16, g) * 255;
        xColor.blue = @intCast(u16, b) * 255;
        xColor.flags = c.DoRed | c.DoGreen | c.DoBlue;
        _ = c.XAllocColor(self.display, self.colormap, &xColor);
        self.colors[index] = xColor.pixel;
        // TODO: why does AllocNamedColor not work
        //var name: []const u8 = "red\\0";
        //const name: []const u8 = "red";
        //const namePtr: [*]const u8 = name.ptr;
        //var res = c.XAllocNamedColor(display, colormap, namePtr, &color, &color);
    }

    fn setForegroundColor(self: Self, gc: c.GC, index: usize) void {
        _ = c.XSetForeground(self.display, gc, self.colors[index]);
    }

    fn hideWindow(self: Self, window: c.Window) void {
        // TODO: better way to hide
        _ = c.XMoveWindow(self.display, window, -4000, 0);
    }

    fn focusWindow(self: Self, window: c.Window) void {
        _ = c.XSetInputFocus(self.display, window, c.PointerRoot, c.CurrentTime);
    }
};

//_ = c.XSetErrorHandler(errorHandler);
//extern fn errorHandler(d: ?*c.Display, e: [*c]c.XErrorEvent) c_int {
//    warn("ERRRROR\n");
//    return 0;
//}
