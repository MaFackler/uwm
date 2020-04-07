const std = @import("std");
const wm = @import("wm.zig");
const assert = std.debug.assert;

test "WorkspaceAddWindow and WorkspaceRemoveWindow" {
    var workspace = wm.Workspace{};
    assert(workspace.amountOfWindows == 0);

    wm.WorkspaceAddWindow(&workspace, 1337);
    assert(workspace.amountOfWindows == 1);
    assert(workspace.windows[0] == 1337);

    wm.WorkspaceAddWindow(&workspace, 1338);
    assert(workspace.amountOfWindows == 2);
    assert(workspace.windows[0] == 1337);
    assert(workspace.windows[1] == 1338);

    wm.WorkspaceAddWindow(&workspace, 1339);
    assert(workspace.amountOfWindows == 3);
    assert(workspace.windows[0] == 1337);
    assert(workspace.windows[1] == 1338);
    assert(workspace.windows[2] == 1339);

    wm.WorkspaceRemoveWindow(&workspace, 1338);
    assert(workspace.amountOfWindows == 2);
    assert(workspace.windows[0] == 1337);
    assert(workspace.windows[1] == 1339);
}
