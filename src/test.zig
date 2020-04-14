const std = @import("std");
const wm = @import("wm.zig");
const assert = std.debug.assert;

test "add and remove windows" {
    var workspace = wm.Workspace{};
    assert(workspace.amountOfWindows == 0);
    assert(workspace.focusedWindow == 0);

    workspace.addWindow(1337);
    assert(workspace.amountOfWindows == 1);
    assert(workspace.windows[0] == 1337);
    assert(workspace.focusedWindow == 0);

    workspace.addWindow(1338);
    assert(workspace.amountOfWindows == 2);
    assert(workspace.windows[0] == 1337);
    assert(workspace.windows[1] == 1338);
    assert(workspace.focusedWindow == 1);

    workspace.addWindow(1339);
    assert(workspace.amountOfWindows == 3);
    assert(workspace.windows[0] == 1337);
    assert(workspace.windows[1] == 1338);
    assert(workspace.windows[2] == 1339);
    assert(workspace.focusedWindow == 2);

    assert(workspace.getWindowIndex(133) == -1);
    assert(workspace.getWindowIndex(1337) == 0);
    assert(workspace.getWindowIndex(1338) == 1);
    assert(workspace.getWindowIndex(1339) == 2);


    workspace.removeWindow(1338);
    assert(workspace.amountOfWindows == 2);
    assert(workspace.windows[0] == 1337);
    assert(workspace.windows[1] == 1339);
    assert(workspace.focusedWindow == 1);

    workspace.removeWindow(1337);
    assert(workspace.amountOfWindows == 1);
    assert(workspace.windows[0] == 1339);
    assert(workspace.focusedWindow == 0);
}
