const std = @import("std");
const c = @import("c.zig");

pub const Draw = struct {
    window: c.Window = undefined,
    display: *c.Display = undefined,
    drawable: c.Drawable = undefined,
    gc: c.GC = undefined,
    _width: u32,
    _height: u32,

    const Self = *Draw;
    pub fn init(self: Self, display: *c.Display, window: c.Window, xscreen: i32, width: u32, height: u32) void {
        self.display = display;
        self.window = window;
        self._width = width;
        self._height = height;
        self.drawable = c.XCreatePixmap(display, window, self._width, self._height, @intCast(c_uint, c.XDefaultDepth(display, xscreen)));
        self.gc = c.XCreateGC(display, window, 0, null);
        _ = c.XSetFillStyle(display, self.gc, c.FillSolid);
    }

    pub fn setForeground(self: Self, color: u64) void {
        _ = c.XSetForeground(self.display, self.gc, color);
    }

    pub fn drawText(self: Self, font: *c.XftFont, color: *c.XColor, x: i32, y: i32, text: []const u8) void {
        var renderColor: c.XRenderColor = undefined;
        renderColor.red = color.red;
        renderColor.green = color.green;
        renderColor.blue = color.blue;
        renderColor.alpha = 65535;
        var draw: *c.XftDraw = undefined;
        var visual = c.XDefaultVisual(self.display, 0);
        var colormap = c.XDefaultColormap(self.display, 0);

        var xftColor: c.XftColor = undefined;
        _ = c.XftColorAllocValue(self.display, visual, colormap, &renderColor, &xftColor);
        defer c.XftColorFree(self.display, visual, colormap, &xftColor);

        draw = c.XftDrawCreate(self.display, self.window, visual, colormap).?;
        defer c.XftDrawDestroy(draw);

        var width: u32 = 0;
        var height: u32 = 0;
        self.getTextDimensions(font, text, &width, &height);
        c.XftDrawString8(draw, &xftColor, font, x, y + @intCast(i32, height), text.ptr, @intCast(i32, text.len));
    }

    pub fn getTextDimensions(self: Self, font: *c.XftFont, text: []const u8, width: *u32, height: *u32) void {
        // TODO: c style function return tuple or vec2
        var glyphInfo: c.XGlyphInfo = undefined;
        c.XftTextExtentsUtf8(self.display, font, text.ptr, @intCast(i32, text.len), &glyphInfo);
        width.* = @intCast(u32, glyphInfo.xOff);
        height.* = @intCast(u32, font.ascent + font.descent);
    }

    pub fn fillRect(self: Self, x: i32, y: i32, width: u32, height: u32) void {
        _ = c.XFillRectangle(self.display, self.drawable, self.gc, x, y, width, height);
    }

    pub fn render(self: Self) void {
        _ = c.XCopyArea(self.display, self.drawable, self.window, self.gc, 0, 0, self._width, self._height, 0, 0);
    }

    pub fn free(self: Self) void {
        _ = c.XFreePixmap(self.display, self.drawable);
        _ = c.XFreeGC(self.display, self.gc);
    }
};
