const wm = @import("wm.zig");
const X = @import("x.zig");
const config = @import("config.zig");

pub const Layout = struct {
    x: i32,
    y: i32,
    width: u32,
    height: u32,

    const Self = *Layout;
    fn stack(self: Self, workspace: *wm.Workspace, xlib: *X.Xlib) void {
        if (workspace.amountOfWindows == 1) {
            xlib.resize(workspace.windows[0], self.x, self.y, self.width, self.height);
        } else {

            for (workspace.windows[0..workspace.amountOfWindows]) |window, i| {
                var w = @divFloor(self.width - (3 * config.gapsize), 2);
                var h = self.height - 2 * config.gapsize;
                var x: i32 = self.x + @intCast(i32, config.gapsize);
                var y: i32 = self.y + @intCast(i32, config.gapsize);


                if (i > 0) {
                    var amountOfHorizontalGaps = workspace.amountOfWindows - 2;
                    var amountRightWindows = workspace.amountOfWindows - 1;
                    x = x + @intCast(i32, w + config.gapsize);
                    h = @divTrunc(h - (amountOfHorizontalGaps * config.gapsize), amountRightWindows);
                    y = y + @intCast(i32, (i - 1) * (config.gapsize + h));
                }

                xlib.resize(window, x, y, w, h);
            }
        }
    }
};


