const std = @import("std");

pub const Workspace = struct {
    windows: [8]u64 = undefined,
    amountOfWindows: u32 = 0,
};

pub fn WorkspaceRemoveWindow(workspace: *Workspace, window: u84) void {
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
