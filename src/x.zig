const std = @import("std");
const c = @import("c.zig");
const panic = std.debug.panic;

pub const Xlib = struct {
    display: *c.Display = undefined,
    screen: i32 = 0,
    root: c.Window = undefined,
    font: *c.XftFont = undefined,

    const Self = *Xlib;
    fn init(self: Self) void {
        self.display = c.XOpenDisplay(null) orelse {
            panic("unable to create window");
        };
        self.screen = c.XDefaultScreen(self.display);
        self.root = c.XRootWindow(self.display, self.screen);
        var fontname: []const u8 = "Ubuntu";
        self.font = c.XftFontOpenName(self.display, self.screen, fontname.ptr);
        if (self.font == undefined) {
            panic("could not load font");
        }


        var cursorNormal = c.XCreateFontCursor(self.display, 2);
        var windowAttributes: c.XSetWindowAttributes = undefined;
        windowAttributes.event_mask = c.SubstructureNotifyMask | c.SubstructureRedirectMask | c.KeyPressMask | c.EnterWindowMask | c.FocusChangeMask | c.PropertyChangeMask | c.PointerMotionMask;
        windowAttributes.cursor = cursorNormal;
        _ = c.XChangeWindowAttributes(self.display, self.root, c.CWEventMask | c.CWCursor, &windowAttributes);
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

    fn grabKey(self: Self, mask: u32, key: c.KeySym) void {
        var code = c.XKeysymToKeycode(self.display, key);
        _ = c.XGrabKey(self.display, code, mask, self.root, 1, c.GrabModeAsync, c.GrabModeAsync);
    }

    fn closeWindow(self: Self, window: c.Window) void {
        _ = c.XKillClient(self.display, window);
    }



    fn hideWindow(self: Self, window: c.Window) void {
        // TODO: better way to hide
        _ = c.XMoveWindow(self.display, window, -4000, 0);
    }

    fn focusWindow(self: Self, window: c.Window) void {
        _ = c.XSetInputFocus(self.display, window, c.PointerRoot, c.CurrentTime);
    }
    
    // TODO: API is crap -> string handling?
    fn getWindowName(self: Self, window: c.Window, textProperty: *c.XTextProperty) void {
        var name: []const u8 = "_NET_WM_NAME";
        var atom = c.XInternAtom(self.display, name.ptr, 0);
        std.debug.warn("ATOM IS {}\n", atom);
        var res = c.XGetTextProperty(self.display, window, textProperty, atom);
        std.debug.assert(res != 0);
    }

    fn freeWindowName(self: Self, textProperty: *c.XTextProperty) void {
        _ = c.XFree(textProperty.value);
        //_ = c.XFree(textProperty);
    }

    fn createWindow(self: Self, x: i32, y: i32, width: u32, height: u32) c.Window {
        var attributes: c.XSetWindowAttributes = undefined;
        attributes.background_pixel = c.ParentRelative;
        attributes.event_mask = c.ButtonPressMask | c.ExposureMask;
        var res = c.XCreateWindow(self.display,
                                  self.root,
                                  x, y,
                                  width, height,
                                  0,
                                  c.XDefaultDepth(self.display, self.screen),
                                  c.CopyFromParent,
                                  c.XDefaultVisual(self.display, self.screen),
                                  c.CWEventMask | c.CWBackPixel,
                                  &attributes);
        _ = c.XMapWindow(self.display, res);
        return res;
    }

    fn getWindowWidth(self: Self, window: c.Window) u32 {
        var rootReturn: c.Window = undefined;
        var x: c_int = 0;
        var y: c_int = 0;
        var width: c_uint = 0;
        var height: c_uint = 0;
        var borderWidth: c_uint = 0;
        var depth: c_uint = 0;
        _ = c.XGetGeometry(self.display, window, &rootReturn,
                           &x, &y,
                           &width, &height,
                           &borderWidth, &depth);
        return width;
    }

    fn getWindowHeight(self: Self, window: c.Window) u32 {
        var rootReturn: c.Window = undefined;
        var x: c_int = 0;
        var y: c_int = 0;
        var width: c_uint = 0;
        var height: c_uint = 0;
        var borderWidth: c_uint = 0;
        var depth: c_uint = 0;
        _ = c.XGetGeometry(self.display, window, &rootReturn,
                           &x, &y,
                           &width, &height,
                           &borderWidth, &depth);
        std.debug.warn("hey {} {}\n", width, height);
        return height;
    }

    fn resize(self: Self, window: c.Window, x: i32, y: i32, width: u32, height: u32) void {
        var changes: c.XWindowChanges = undefined;
        changes.x = x;
        changes.y = y;
        changes.width = @intCast(c_int, width);
        changes.height = @intCast(c_int, height);
        _ = c.XConfigureWindow(self.display, window, c.CWX | c.CWY | c.CWWidth | c.CWHeight, &changes);
    }

    fn focus(self: Self, window: c.Window) void {
        c.XSetInputFocus(self.display, window, c.RevertToPointerRoot, c.CurrentTime);
    }

};

//_ = c.XSetErrorHandler(errorHandler);
//extern fn errorHandler(d: ?*c.Display, e: [*c]c.XErrorEvent) c_int {
//    warn("ERRRROR\n");
//    return 0;
//}
