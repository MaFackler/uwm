const std = @import("std");
const config = @import("config.zig");
const main = @import("main.zig");
const linux = std.os.linux;

const c = @import("c.zig");

pub fn windowClose(window: u64, arg: config.Arg) void {
    var workspace = main.manager.getActiveScreen().getActiveWorkspace();
    var win = workspace.getFocusedWindow();
    main.xlib.closeWindow(win);
    workspace.removeWindow(win);
}

pub fn run(window: u64, arg: config.Arg) void {
    //var cmd cmd: []const []const u8
    var cmd = arg.StringList;
    const rc = linux.fork();
    if (rc == 0) {
        var allocator = std.heap.page_allocator;
        var e = std.ChildProcess.exec(.{
                .allocator=allocator,
                .argv=cmd,
                .cwd=null,
                .max_output_bytes=2 * 1024
            });
        linux.exit(0);
    }
}

pub fn notify(window: u64, arg: config.Arg) void {
    var msg = arg.String;
    var cmd = [_][]const u8{
        "notify-send",
        "-t",
        "2000",
        msg,
    };
    var argToPass = config.Arg{.StringList=&cmd};
    run(window, argToPass);
}

pub fn exit(window: u64, arg: config.Arg) void {
    main.manager.running = false;
}

pub fn doLayout(window: u64, arg: config.Arg) void {
}

pub fn windowMove(window: u64, arg: config.Arg) void {
    // TODO: xlib direcly called maybe move to x.zig
    var mouseEvent: c.XEvent = undefined;
    // NOTE: have to grab pointer that quering events XMaskEvent will work
    var xlib = main.xlib;
    _ = c.XGrabPointer(xlib.display, xlib.root, 0, c.ButtonReleaseMask | c.PointerMotionMask, c.GrabModeAsync, c.GrabModeAsync,
                  0, xlib.cursor, c.CurrentTime);
    var maskToQuery = c.ButtonReleaseMask | c.PointerMotionMask | c.ExposureMask | c.SubstructureRedirectMask;
    // TODO: find better while construct in zig
    _ = c.XMaskEvent(xlib.display, maskToQuery, &mouseEvent);

    std.debug.warn("before dragStartPos\n", .{});
    var dragStartPos = main.xlib.getPointerPos(window);
    std.debug.warn("after dragStartPos {} {}\n", .{dragStartPos[0], dragStartPos[1]});

    while (mouseEvent.type != c.ButtonRelease) {
        switch (mouseEvent.type) {
            c.MotionNotify => {
                xlib.move(window,
                          mouseEvent.xmotion.x - dragStartPos[0],
                          mouseEvent.xmotion.y - dragStartPos[1]);
            },
            else => {},
        }

        _ = c.XMaskEvent(xlib.display, maskToQuery, &mouseEvent);
    }

    _ = c.XUngrabPointer(xlib.display, c.CurrentTime);
}

pub fn windowNext(window: u64, arg: config.Arg) void {
    var workspace = main.manager.getActiveScreen().getActiveWorkspace();
    main.windowFocus(workspace.getNextWindow());
}

pub fn windowPrevious(window: u64, arg: config.Arg) void {
    var workspace = main.manager.getActiveScreen().getActiveWorkspace();
    main.windowFocus(workspace.getPreviousWindow());
}

pub fn workspaceShow(window: u64, arg: config.Arg) void {
    var index = arg.UInt;
    var screen = main.manager.getActiveScreen();
    var workspace = screen.getActiveWorkspace();
    for (workspace.windows[0..workspace.amountOfWindows]) |win| {
        main.xlib.hideWindow(win);
    }
    screen.workspaceFocus(index);
    workspace = screen.getActiveWorkspace();
    main.layouts[main.manager.activeScreenIndex].stack(workspace, &main.xlib);
    main.drawBar();
    if (workspace.amountOfWindows > 0) {
        main.windowFocus(workspace.getFocusedWindow());
    } else {
        main.xlib.focusWindow(main.xlib.root);
    }
}

pub fn workspaceFocusPrevious(window: u64, arg: config.Arg) void {
    var screen = main.manager.getActiveScreen();
    var a = config.Arg{.UInt=screen.previousWorkspace};
    workspaceShow(window, a);
}

pub fn screenSelectByDelta(window: u64, arg: config.Arg) void {
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
    var windowToFocus = main.xlib.root;
    var screen = main.manager.getActiveScreen();
    var workspace = screen.getActiveWorkspace();
    if (workspace.amountOfWindows > 0) {
        windowToFocus = workspace.getFocusedWindow();
    }
    main.windowFocus(windowToFocus);

    main.xlib.setPointer(screen.info.x + @intCast(i32, @divFloor(screen.info.width, 2)),
                         screen.info.y + @intCast(i32, @divFloor(screen.info.height, 2)));

    main.drawBar();
}

