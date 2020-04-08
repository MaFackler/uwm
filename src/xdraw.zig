const std = @import("std");
const c = @import("c.zig");

pub const DrawableWindow = struct {
    window: c.Window = undefined,
    display: *c.Display = undefined,
    drawable: c.Drawable = undefined,
    gc: c.GC = undefined,
    x: i32,
    y: i32,
    width: u32,
    height: u32,

    const Self = *DrawableWindow;
    pub fn init(self: Self, display: *c.Display, root: c.Window, xscreen: i32) void {
        self.display = display;
        var attributes: c.XSetWindowAttributes = undefined;
        attributes.background_pixel = c.ParentRelative;
        attributes.event_mask = c.ButtonPressMask | c.ExposureMask;

        self.window = c.XCreateWindow(display, root, self.x, self.y, self.width, self.width, 0, c.XDefaultDepth(display, xscreen), c.CopyFromParent, c.XDefaultVisual(display, xscreen), c.CWEventMask | c.CWBackPixel, &attributes);
        _ = c.XMapWindow(display, self.window);
        self.drawable = c.XCreatePixmap(display, self.window, self.width, self.height, @intCast(c_uint, c.XDefaultDepth(display, xscreen)));
        self.gc = c.XCreateGC(display, root, 0, null);
        _ = c.XSetFillStyle(display, self.gc, c.FillSolid);
    }

    pub fn fillRect(self: Self, x: i32, y: i32, width: u32, height: u32) void {
        _ = c.XFillRectangle(self.display, self.drawable, self.gc, 0, 0, 16, 16);
    }

    pub fn render(self: Self) void {
        _ = c.XCopyArea(self.display, self.drawable, self.window, self.gc, 0, 0, self.width, self.height, self.x, self.y);
    }

    pub fn delete(self: Self) void {
        _ = c.XFreePixmap(self.display, self.drawable);
        _ = c.XFreeGC(self.display, self.gc);
    }
};
