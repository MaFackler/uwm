const std = @import("std");
const config = @import("config.zig");
const main = @import("main.zig");
const linux = std.os.linux;

pub fn windowClose(arg: config.Arg) void {
    var workspace = main.manager.getActiveScreen().getActiveWorkspace();
    main.xlib.closeWindow(workspace.windows[@intCast(u32, workspace.focusedWindow)]);
    // TODO: remove from workspace
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
    // TODO: bar height
    main.stack(workspace, screen.info.width, screen.info.height - 16);
    main.drawBar();
    main.xlib.focusWindow(main.xlib.root);
}
