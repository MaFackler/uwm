const std = @import("std");
const c = @import("c.zig");
const panic = std.debug.panic;

pub const Xlib = struct {
    display: *c.Display = undefined,
    screen: i32 = 0,
    root: c.Window = undefined,
    font: *c.XftFont = undefined,
    cursor: u64 = undefined,

    const Self = *Xlib;
    fn init(self: Self, fontname: []const u8) void {
        self.display = c.XOpenDisplay(null) orelse {
            @panic("unable to create window");
        };
        self.screen = c.XDefaultScreen(self.display);
        self.root = c.XRootWindow(self.display, self.screen);
        self.font = c.XftFontOpenName(self.display, self.screen, fontname.ptr);
        if (self.font == undefined) {
            @panic("could not load font");
        }


        self.cursor = c.XCreateFontCursor(self.display, 2);
        var windowAttributes: c.XSetWindowAttributes = undefined;
        windowAttributes.event_mask = c.SubstructureNotifyMask | c.SubstructureRedirectMask | c.KeyPressMask | c.EnterWindowMask | c.FocusChangeMask | c.PropertyChangeMask | c.PointerMotionMask | c.NoEventMask;
        windowAttributes.cursor = self.cursor;
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

    fn grabButton(self: Self, window: c.Window) void {
        _ = c.XGrabButton(self.display, c.AnyButton, c.AnyModifier, window, 0,
                    c.ButtonPressMask, c.GrabModeSync, c.GrabModeSync, 0, 0);
    }

    fn ungrabButton(self: Self, window: c.Window) void {
        _ = c.XUngrabButton(self.display, c.AnyButton, c.AnyModifier, window);
    }

    fn closeWindow(self: Self, window: c.Window) void {
        _ = c.XKillClient(self.display, window);
    }

    fn hideWindow(self: Self, window: c.Window) void {
        // TODO: better way to hide
        self.move(window, -4000, 0);
    }

    fn move(self: Self, window: c.Window, x: i32, y: i32) void {
        _ = c.XMoveWindow(self.display, window, x, y);
    }

    fn moveByDelta(self: Self, window: c.Window, x: i32, y: i32) void {
        var windowDimension = self.getWindowPos(window);
        self.move(window, @intCast(i32, windowDimension[0]) + x, @intCast(i32, windowDimension[1]) + y);
    }

    fn focusWindow(self: Self, window: c.Window) void {
        _ = c.XSetInputFocus(self.display, window, c.PointerRoot, c.CurrentTime);
    }
    
    // TODO: API is crap -> string handling?
    fn getWindowName(self: Self, window: c.Window, textProperty: *c.XTextProperty) bool {
        var name: []const u8 = "_NET_WM_NAME";
        var atom = c.XInternAtom(self.display, name.ptr, 0);
        var res = c.XGetTextProperty(self.display, window, textProperty, atom);
        return res != 0;
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

    fn getWindowDimensions(self: Self, window: c.Window) @Vector(2, u32) {

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
        return [2]u32{width, height};
    }

    fn getWindowPos(self: Self, window: c.Window) @Vector(2, i32) {
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
        return [2]i32{x, y};
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

    fn windowSetBorder(self: Self, window: c.Window, color: u64, borderWidth: i32) void {
        _ = c.XSetWindowBorder(self.display, window, color);
        var changes: c.XWindowChanges = undefined;
        changes.border_width = borderWidth;
        _ = c.XConfigureWindow(self.display, window, c.CWBorderWidth, &changes);
    }

    fn setPointer(self: Self, x: i32, y: i32) void {
        var res = c.XWarpPointer(self.display, self.root, self.root, 0, 0, 0, 0, x, y);
        _ = c.XFlush(self.display);
        _ = c.XSync(self.display, 0);
    }

    fn getPointerPos(self: Self, window: c.Window) @Vector(2, i32) {
        var i: i32 = 0;
        var x: i32 = 0;
        var y: i32 = 0;
        var ui: u32 = 0;
        var win: c.Window = 0;
        _ = c.XQueryPointer(self.display, window, &win, &win, &i, &i, &x, &y, &ui);
        return [2]i32{x, y};

    }

    fn isFixed(self: Self, window: c.Window) bool {

        var res = false;
        var hints: c.XSizeHints = undefined;
        var tempHints: c.XSizeHints = undefined;
        // TODO: remove this
        tempHints.min_width = 0;
        tempHints.min_height = 0;
        tempHints.max_width = -1;
        tempHints.max_height = -1;
        var foo: i64 = 0;
        _ = c.XGetWMNormalHints(self.display, window, &hints, &foo);
        if (hints.flags & c.PBaseSize == c.PBaseSize) {
            std.debug.warn("PBaseSize {} {}\n", .{hints.base_width, hints.base_height});
        }
        if (hints.flags & c.PMinSize == c.PMinSize) {
            std.debug.warn("PMin {} {}\n", .{hints.min_width, hints.min_height});
            tempHints.min_width = hints.min_width;
            tempHints.min_height = hints.min_height;
        }
        if (hints.flags & c.PMaxSize == c.PMaxSize) {
            std.debug.warn("PMaxSize {} {}\n", .{hints.max_width, hints.max_height});
            tempHints.max_width = hints.max_width;
            tempHints.max_height = hints.max_height;
        }

        res = tempHints.min_width == tempHints.max_width and tempHints.min_height == tempHints.max_height;
        return res;
    }

};
