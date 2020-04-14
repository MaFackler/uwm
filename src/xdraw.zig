const std = @import("std");
const c = @import("c.zig");

pub const Draw = struct {
    window: c.Window = undefined,
    display: *c.Display = undefined,
    drawable: c.Drawable = undefined,
    gc: c.GC = undefined,
    colormap: c.Colormap = undefined,
    _width: u32,
    _height: u32,
    // TODO: maybe dynamic array to support more than 16 colors
    // TODO: no need to be defined for each Draw instance
    colors: [16]u64 = undefined,

    const Self = *Draw;
    pub fn init(self: Self, display: *c.Display, window: c.Window, xscreen: i32, width: u32, height: u32) void {
        self.display = display;
        self.window = window;
        self.colormap = c.XDefaultColormap(self.display, xscreen);
        self._width = width;
        self._height = height;
        self.drawable = c.XCreatePixmap(display, window, self._width, self._height, @intCast(c_uint, c.XDefaultDepth(display, xscreen)));
        self.gc = c.XCreateGC(display, window, 0, null);
        _ = c.XSetFillStyle(display, self.gc, c.FillSolid);
    }

    pub fn setColor(self: Self, index: usize) void {
        //var color: c.XColor = undefined;
        //color.red = 32000;
        //color.green = 0;
        //color.blue = 0;
        //color.flags = c.DoRed | c.DoGreen | c.DoBlue;
        _ = c.XSetForeground(self.display, self.gc, self.colors[index]);
        //_ = c.XSetForeground(self.display, self.gc, c.XWhitePixel(self.display, xscreen));
        //c.XFreeColor(color);
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

    pub fn drawText(self: Self, font: *c.XftFont, x: i32, y: i32, text: []const u8) void {
        var renderColor: c.XRenderColor = undefined;
        // TODO: use defined colors
        renderColor.red = 65535;
        renderColor.green = 0;
        renderColor.blue = 0;
        renderColor.alpha = 65535;
        var draw: *c.XftDraw = undefined;
        var visual = c.XDefaultVisual(self.display, 0);
        var colormap = c.XDefaultColormap(self.display, 0);

        var xftColor: c.XftColor = undefined;
        _ = c.XftColorAllocValue(self.display, visual, colormap, &renderColor, &xftColor);
        defer c.XftColorFree(self.display, visual, colormap, &xftColor);

        draw = c.XftDrawCreate(self.display, self.window, visual, colormap).?;
        defer c.XftDrawDestroy(draw);

        c.XftDrawString8(draw, &xftColor, font, x, y, text.ptr, @intCast(i32, text.len));
        

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
