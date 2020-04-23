const std = @import("std");
const wm = @import("wm.zig");
const assert = std.debug.assert;

test "add and remove windows" {
    var workspace = wm.Workspace{};
    assert(workspace.amountOfWindows == 0);
    assert(workspace.focusedWindow == 0);

    assert(true == workspace.addWindow(1337));
    assert(workspace.amountOfWindows == 1);
    assert(workspace.windows[0] == 1337);
    assert(workspace.focusedWindow == 0);

    assert(true == workspace.addWindow(1338));
    assert(workspace.amountOfWindows == 2);
    assert(workspace.windows[0] == 1337);
    assert(workspace.windows[1] == 1338);
    assert(workspace.focusedWindow == 0);

    assert(true == workspace.addWindow(1339));
    assert(workspace.amountOfWindows == 3);
    assert(workspace.windows[0] == 1337);
    assert(workspace.windows[1] == 1338);
    assert(workspace.windows[2] == 1339);
    assert(workspace.focusedWindow == 0);

    assert(workspace.getWindowIndex(133) == -1);
    assert(workspace.getWindowIndex(1337) == 0);
    assert(workspace.getWindowIndex(1338) == 1);
    assert(workspace.getWindowIndex(1339) == 2);


    workspace.removeWindow(1338);
    assert(workspace.amountOfWindows == 2);
    assert(workspace.windows[0] == 1337);
    assert(workspace.windows[1] == 1339);
    assert(workspace.focusedWindow == 0);

    workspace.removeWindow(1337);
    assert(workspace.amountOfWindows == 1);
    assert(workspace.windows[0] == 1339);
    assert(workspace.focusedWindow == 0);
}

test "next and previousWindow" {
    var workspace = wm.Workspace{};
    _ = workspace.addWindow(1);
    _ = workspace.addWindow(2);
    _ = workspace.addWindow(3);

    assert(1 == workspace.getPreviousWindow());
    assert(2 == workspace.getNextWindow());
}

test "maximum windows" {
    var workspace = wm.Workspace{};
    var i: usize = 0;
    while (i < 8) {
        assert(true == workspace.addWindow(i));
        i += 1;
    }

    assert(false == workspace.addWindow(1337));
    assert(workspace.amountOfWindows == 8);
}

test "workspaceFocus" {
    var screen = wm.Screen{.info=undefined, .workspaces=undefined};

    assert(0 == screen.previousWorkspace);
    screen.workspaceFocus(2);
    assert(2 == screen.activeWorkspace);
    assert(0 == screen.previousWorkspace);
}




