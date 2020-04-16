const wm = @import("wm.zig");
const X = @import("x.zig");

pub const Layout = struct {
    x: i32,
    y: i32,
    width: u32,
    height: u32,

    const Self = *Layout;
    fn stack(self: Self, workspace: *wm.Workspace, xlib: *X.Xlib) void {
        if (workspace.amountOfWindows == 1) {
            xlib.resize(workspace.windows[0], self.x, self.y, self.width - 1, self.height);
        } else {
            for (workspace.windows[0..workspace.amountOfWindows]) |window, i| {
                var x: i32 = self.x;
                var y: i32 = self.y;
                var w = @divFloor(self.width, 2) - 1;
                var h = self.height;

                if (i > 0) {
                    x = self.x + @divFloor(@intCast(i32, self.width), 2);
                    var divisor: u32 = workspace.amountOfWindows - 1;
                    h = @divTrunc(self.height, divisor);
                    y = self.y + @intCast(i32, (h * (i - 1)));
                }

                xlib.resize(window, x, y, w, h);
            }
        }
    }
};


