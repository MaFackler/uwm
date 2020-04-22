const c = @import("c.zig");

pub const Colors = struct {
    // TODO: maybe dynamic array to support more than 16 colors
    // TODO: no need to be defined for each Draw instance
    colors: [16]c.XColor = undefined,
    colormap: c.Colormap = undefined,

    const Self = *Colors;
    pub fn init(self: Self, display: *c.Display, xscreen: i32) void {
        self.colormap = c.XDefaultColormap(display, xscreen);
    }

    fn addColor(self: Self, display: *c.Display, index: usize, r: u8, g: u8, b: u8) void {
        var xColor: *c.XColor = &self.colors[index];
        xColor.red = @intCast(u16, r) * 255;
        xColor.green = @intCast(u16, g) * 255;
        xColor.blue = @intCast(u16, b) * 255;
        xColor.flags = c.DoRed | c.DoGreen | c.DoBlue;
        _ = c.XAllocColor(display, self.colormap, xColor);
        // TODO: why does AllocNamedColor not work
        //var name: []const u8 = "red\\0";
        //const name: []const u8 = "red";
        //const namePtr: [*]const u8 = name.ptr;
        //var res = c.XAllocNamedColor(display, colormap, namePtr, &color, &color);
    }

    fn getColorPixel(self: Self, index: usize) u64 {
        return self.colors[index].pixel;
    }

    fn getColor(self: Self, index: usize) *c.XColor {
        return &self.colors[index];
    }
};
