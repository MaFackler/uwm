const std = @import("std");

pub const Screen = struct {
    info: ScreenInfo,
    workspaces: [8]Workspace,
    activeWorkspace: u32,
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
    focusedWindow: i32 = 0,
};

pub fn WorkspaceGetWindowIndex(workspace: *Workspace, window: u64) i32 {
    var res: i32 = -1;
    for (workspace.windows) |win, i| {
        if (win == window) {
            res = @intCast(i32, i);
            break;
        }
    }
    return res;
}

pub fn WorkspaceRemoveWindow(workspace: *Workspace, window: u64) void {
    var removeIndex: usize = 0;
    var found = false;
    for (workspace.windows) |win, i| {
        if (win == window) {
            removeIndex = i;
            found = true;
            break;
        }
    }
    std.debug.warn("index is {}\n", removeIndex);

    if (found) {
        for (workspace.windows[removeIndex..workspace.amountOfWindows]) |win, i| {
            var index = removeIndex + i;
            workspace.windows[index] = workspace.windows[index + 1];
        }
        workspace.amountOfWindows -= 1;
    }
}

pub fn WorkspaceAddWindow(workspace: *Workspace, window: u64) void {
    // TODO: overflow of windows array
    workspace.windows[workspace.amountOfWindows] = window;
    workspace.amountOfWindows += 1;
}
