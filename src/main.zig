const c = @import("c.zig");
const std = @import("std");
const wm = @import("wm.zig");
const warn = std.debug.warn;
const panic = std.debug.panic;
const linux = std.os.linux;

var display: ?*c.Display = undefined;
//var window: c.Window = undefined;
var root: c.Window = undefined;
const Allocator = std.mem.Allocator;

var workspaces: [8]wm.Workspace = undefined;
var activeWorkspace: u32 = 0;
var displayWidth: i32 = 0;
var displayHeight: i32 = 0;

//var windows = std.AutoHashMap(u64, Workspace).init(std.heap.direct_allocator);

fn WindowClose(window: u64) void {
    _ = c.XKillClient(display, window);
}

pub fn isWindowRegistered(window: c.Window) bool {
    var workspace = getActiveWorkspace();
    // TODO: array contains??
    var res = false;
    for (workspace.windows) |win| {
        if (win == window) {
            res = true;
        }
    }
    return res;
}

pub fn getActiveWorkspace() *wm.Workspace {
    return &workspaces[activeWorkspace];
}

pub fn onConfigureRequest(e: *c.XEvent) void {
    var ev = e.xconfigurerequest;
    warn("Configure Request {}\n", ev.window);
    if (!isWindowRegistered(ev.window)) {
        warn("Window is not registered\n");
        var changes: c.XWindowChanges = undefined;
        changes.height = e.xconfigurerequest.height;
        changes.border_width = e.xconfigurerequest.border_width;
        changes.sibling = e.xconfigurerequest.above;
        changes.stack_mode = e.xconfigurerequest.detail;
        _ = c.XConfigureWindow(display, ev.window, @intCast(c_uint, ev.value_mask), &changes);
    } else {
        warn("Window is already registered\n");
    }
}

pub fn onDestroyNotify(e: *c.XEvent) void {
    var ev = e.xdestroywindow;
    warn("onDestroyNotify {}\n", ev.window);
    var workspace = getActiveWorkspace();
    wm.WorkspaceRemoveWindow(workspace, ev.window);
}

fn onEnterNotify(e: *c.XEvent) void {
    var ev = e.xcrossing;
    var workspace = getActiveWorkspace();
    var index = wm.WorkspaceGetWindowIndex(workspace, ev.window);
    if (index >= 0) {
        workspace.focusedWindow = index;
    }
}

fn onUnmapNotify(e: *c.XEvent) void {
    var ev = e.xunmap;
    warn("onUnmapNotify {}\n", ev.window);
    var workspace = getActiveWorkspace();
    wm.WorkspaceRemoveWindow(workspace, ev.window);
    stack(workspace);
}

pub fn stack(workspace: *wm.Workspace) void {
    if (workspace.amountOfWindows == 1) {
        resize(workspace.windows[0], 0, 0, displayWidth, displayHeight);
    } else {
        for (workspace.windows[0..workspace.amountOfWindows]) |window, i| {
            var x: i32 = 0;
            var y: i32 = 0;
            var width = @divFloor(displayWidth, 2);
            var height = displayHeight;

            if (i > 0) {
                x = @divFloor(displayWidth, 2);
                var divisor: i32 = @intCast(i32, workspace.amountOfWindows) - 1;
                height = @divFloor(displayHeight, divisor);
                y = (height * (@intCast(i32, i) - 1));
            }

            warn("{} {} {} {}\n", x, y, width, height);
            resize(window, x, y, width, height);
        }
    }
}

pub fn onMapRequest(e: *c.XEvent) void {
    var ev = e.xmap;
    warn("map request {}\n", ev.window);
    var workspace = getActiveWorkspace();
    wm.WorkspaceAddWindow(getActiveWorkspace(), ev.window);
    // TODO: check if window actually in workspace
    stack(workspace);
    _ = c.XSelectInput(display, ev.window, c.EnterWindowMask | c.FocusChangeMask);
    _ = c.XMapWindow(display, ev.window);
    _ = c.XSync(display, 1);
}

pub fn sendConfigureEvent(window: c.Window) void {
    var event: c.XConfigureEvent = undefined;
    event.type = c.ConfigureNotify;
    event.display = display;
    event.window = window;
    event.x = 10;
    event.y = 10;
    event.width = 100;
    event.height = 100;
    event.border_width = 2;
    event.override_redirect = 0;
    var res = c.XSendEvent(display, window, 0, c.SubstructureNotifyMask, @ptrCast(*c.XEvent, &event));
    warn("res is {}\n", res);
}

pub fn resize(window: c.Window, x: i32, y: i32, width: i32, height: i32) void {
    var changes: c.XWindowChanges = undefined;
    changes.x = x;
    changes.y = y;
    changes.width = width;
    changes.height = height;
    warn("resize {}\n", window);
    _ = c.XConfigureWindow(display, window, c.CWX | c.CWY | c.CWWidth | c.CWHeight, &changes);
}

pub fn main() void {
    display = c.XOpenDisplay(null) orelse {
        panic("unable to create window");
    };

    defer {
        _ = c.XCloseDisplay(display);
    }

    var screen: i32 = 0;
    screen = c.XDefaultScreen(display);
    var bp: c_ulong = c.XBlackPixel(display, screen);
    var wp: c_ulong = c.XWhitePixel(display, screen);
    root = c.XRootWindow(display, screen);

    displayWidth = @intCast(i32, c.XDisplayWidth(display, screen));
    displayHeight = @intCast(i32, c.XDisplayHeight(display, screen));

    //window = c.XCreateSimpleWindow(display, root, 0, 0, 100, 100, 1, bp, wp);

    var windowAttributes: c.XSetWindowAttributes = undefined;
    windowAttributes.event_mask = c.SubstructureNotifyMask | c.SubstructureRedirectMask | c.KeyPressMask;
    _ = c.XSelectInput(display, root, windowAttributes.event_mask);

    //_ = c.XMapWindow(display, root);
    _ = c.XSync(display, 0);
    var code = c.XKeysymToKeycode(display, c.XK_q);
    _ = c.XGrabKey(display, code, c.Mod4Mask, root, 1, c.GrabModeAsync, c.GrabModeAsync);
    //_ = c.XGrabServer(display);

    var running = true;
    warn("root is {}\n", root);

    while (running) {
        var e: c.XEvent = undefined;
        _ = c.XNextEvent(display, &e);
        //_ = c.XFillRectangle(display, window, c.XDefaultGC(display, screen), 20, 20, 100, 100);

        warn("\nGOT event {}\n", e.type);

        switch (e.type) {
            c.Expose => warn("Expose\n"),
            c.KeyPress => {
                var ev = e.xkey;
                var keysym = c.XKeycodeToKeysym(display, @intCast(u8, ev.keycode), 0);
                warn("key event {}\n", ev);
                var workspace = getActiveWorkspace();

                if (ev.state == c.Mod4Mask) {
                    if (keysym == c.XK_q) {
                        WindowClose(workspace.windows[@intCast(u32, workspace.focusedWindow)]);
                    }
                }

                //if (keysym == c.XK_q) {
                //    //running = false;
                //}
                //if (keysym == c.XK_t) {
                //    const rc = linux.fork();
                //    if (rc == 0) {
                //        var allocator = std.heap.direct_allocator;
                //        warn("Child\n");
                //        _ = try std.ChildProcess.exec(allocator, &[_][]const u8{
                //            "xterm",
                //        }, null, null, 2 * 1024);
                //        warn("after\n");
                //        linux.exit(0);
                //    }
                //    warn("not child\n");
                //}

                //running = false;
            },
            c.ConfigureRequest => {
                onConfigureRequest(&e);
            },
            c.ConfigureNotify => warn("Configure notify\n"),
            c.MapRequest => {
                onMapRequest(&e);
            },
            c.MapNotify => {
                warn("map notify\n");
            },
            c.UnmapNotify => onUnmapNotify(&e),
            c.DestroyNotify => onDestroyNotify(&e),
            c.EnterNotify => onEnterNotify(&e),
            else => warn("not handled {}\n", e.type),
        }
        warn("End loop\n");
    }
}
