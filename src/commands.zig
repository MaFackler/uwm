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
        "1000",
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
    main.xlib.focusWindow(main.xlib.root);
}

