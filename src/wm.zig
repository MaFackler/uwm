const std = @import("std");

pub const maxWindows = 8; 

pub const WindowManager = struct {
    activeScreenIndex: usize = 0,
    amountScreens: usize = 0,
    displayWidth: i32 = 0,
    displayHeight: i32 = 0,
    screens: [maxWindows]Screen = undefined,
    running: bool = false,

    fn getActiveScreen(self: *WindowManager) *Screen {
        var res = &self.screens[self.activeScreenIndex];
        return res;
    }

    fn getScreenIndexOfWindow(self: *WindowManager, window: u64) i32 {
        var res: i32 = -1;
        for (self.screens[0..self.amountScreens]) |*screen, screenIndex| {
            var workspace = screen.getActiveWorkspace();
            var windowIndex = workspace.getWindowIndex(window);
            if (windowIndex >= 0) {
                res = @intCast(i32, screenIndex);
                break;
            }
        }
        return res;
    }
};

pub const Screen = struct {
    info: ScreenInfo,
    workspaces: [8]Workspace,
    activeWorkspace: u32,

    fn getActiveWorkspace(self: *Screen) *Workspace {
        return &self.workspaces[self.activeWorkspace];
    }
};

pub const ScreenInfo = struct {
    x: i32,
    y: i32,
    width: u32,
    height: u32,
};

pub const Workspace = struct {
    windows: [8]u64 = undefined,
    amountOfWindows: u32 = 0,
    focusedWindow: u32 = 0,

    const Self = *Workspace;
    fn hasWindow(self: Self, window: u64) bool {
        // TODO: array contains??
        var res = false;
        for (self.windows) |win| {
            if (win == window) {
                res = true;
                break;
            }
        }
        return res;
    }

    fn getWindowIndex(self: Self, window: u64) i32 {
        var res: i32 = -1;
        for (self.windows) |win, i| {
            if (win == window) {
                res = @intCast(i32, i);
                break;
            }
        }
        return res;
    }
    
    fn getFocusedWindow(self: Self) u64 {
        return self.windows[self.focusedWindow];
    }

    fn removeWindow(self: Self, window: u64) void {
        var removeIndex: usize = 0;
        var found = false;
        for (self.windows) |win, i| {
            if (win == window) {
                removeIndex = i;
                found = true;
                break;
            }
        }
        std.debug.warn("index is {}\n", removeIndex);

        if (removeIndex == self.focusedWindow) {
            self.focusedWindow = 0;
        } else if (removeIndex < self.focusedWindow) {
            self.focusedWindow -= 1;
        }
        
        if (found) {
            for (self.windows[removeIndex..self.amountOfWindows]) |win, i| {
                var index = removeIndex + i;
                self.windows[index] = self.windows[index + 1];
            }
            self.amountOfWindows -= 1;
        }
    }

    fn addWindow(self: Self, window: u64) bool {
        if (self.amountOfWindows == maxWindows) {
            return false;
        }
        self.windows[self.amountOfWindows] = window;
        self.focusedWindow = self.amountOfWindows;
        self.amountOfWindows += 1;
        return true;
    }

};

