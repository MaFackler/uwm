const std = @import("std");
const config = @import("config.zig");
const main = @import("main.zig");
const linux = std.os.linux;

pub fn windowClose(arg: config.Arg) void {
    var workspace = main.manager.getActiveScreen().getActiveWorkspace();
    var window = workspace.getFocusedWindow();
    main.xlib.closeWindow(window);
    workspace.removeWindow(window);
}

pub fn run(arg: config.Arg) void {
    //var cmd cmd: []const []const u8
    var cmd = arg.StringList;
    const rc = linux.fork();
    if (rc == 0) {
        var allocator = std.heap.direct_allocator;
        var e = std.ChildProcess.exec(allocator, cmd, null, null, 2 * 1024);
        linux.exit(0);
    }
}

pub fn notify(arg: config.Arg) void {
    var msg = arg.String;
    var cmd = [_][]const u8{
        "notify-send",
        "-t",
        "2000",
        msg,
    };
    var argToPass = config.Arg{.StringList=&cmd};
    run(argToPass);
}

pub fn exit(arg: config.Arg) void {
    main.manager.running = false;
}

pub fn doLayout(arg: config.Arg) void {
}

pub fn workspaceShow(arg: config.Arg) void {
    var index = arg.UInt;
    var screen = main.manager.getActiveScreen();
    var workspace = screen.getActiveWorkspace();
    for (workspace.windows[0..workspace.amountOfWindows]) |window| {
        main.xlib.hideWindow(window);
    }
    screen.activeWorkspace = index;
    workspace = screen.getActiveWorkspace();
    main.layouts[main.manager.activeScreenIndex].stack(workspace, &main.xlib);
    main.drawBar();
    if (workspace.amountOfWindows > 0) {
        main.windowFocus(workspace.getFocusedWindow());
    } else {
        main.xlib.focusWindow(main.xlib.root);
    }
}

pub fn screenSelectByDelta(arg: config.Arg) void {
    var delta = arg.Int;
    var amount: i32 = @intCast(i32, main.manager.amountScreens);
    var index: i32 = @intCast(i32, main.manager.activeScreenIndex) + delta;
    // TODO: use min and max
    if (index < 0) {
        index = 0;
    } else if (index >= amount) {
        index = amount - 1;
    }
    main.manager.activeScreenIndex = @intCast(u32, index);
    var windowToFoucs = main.xlib.root;
    var screen = main.manager.getActiveScreen();
    var workspace = screen.getActiveWorkspace();
    if (workspace.amountOfWindows > 0) {
        windowToFoucs = workspace.getFocusedWindow();
    }

    main.notifyf("ScreenSelect {}", main.manager.activeScreenIndex);
    main.xlib.setPointer(screen.info.x + @intCast(i32, @divFloor(screen.info.width, 2)),
                         screen.info.y + @intCast(i32, @divFloor(screen.info.height, 2)));

    main.drawBar();
}

