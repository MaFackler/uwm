const config = @import("config.zig");
const c = @import("c.zig");
const X = @import("x.zig");
const std = @import("std");
const wm = @import("wm.zig");
const xdraw = @import("xdraw.zig");
const warn = std.debug.warn;
const panic = std.debug.panic;

const Allocator = std.mem.Allocator;
pub var xlib = X.Xlib{};

// TODO: maybe dynamic arrays
var bar: xdraw.DrawableWindow = undefined;
pub var manager: wm.WindowManager = wm.WindowManager{};

//var windows = std.AutoHashMap(u64, Workspace).init(std.heap.direct_allocator);


pub fn onConfigureRequest(e: *c.XEvent) void {
    var ev = e.xconfigurerequest;
    warn("Configure Request {}\n", ev.window);
    var workspace = manager.getActiveScreen().getActiveWorkspace();
    if (!workspace.hasWindow(ev.window)) {
        warn("Window is not registered\n");
        var changes: c.XWindowChanges = undefined;
        changes.height = e.xconfigurerequest.height;
        changes.border_width = e.xconfigurerequest.border_width;
        changes.sibling = e.xconfigurerequest.above;
        changes.stack_mode = e.xconfigurerequest.detail;
        _ = c.XConfigureWindow(xlib.display, ev.window, @intCast(c_uint, ev.value_mask), &changes);
    } else {
        warn("Window is already registered\n");
    }
}

pub fn onDestroyNotify(e: *c.XEvent) void {
    var ev = e.xdestroywindow;
    warn("onDestroyNotify {}\n", ev.window);
    var screen = manager.getActiveScreen();
    var workspace = screen.getActiveWorkspace();
    wm.WorkspaceRemoveWindow(workspace, ev.window);
}

fn onEnterNotify(e: *c.XEvent) void {
    var ev = e.xcrossing;
    warn("onEnterNotify {}\n", ev.window);
    var screen = manager.getActiveScreen();
    var workspace = screen.getActiveWorkspace();
    var index = wm.WorkspaceGetWindowIndex(workspace, ev.window);
    if (index >= 0) {
        workspace.focusedWindow = index;
    }
}

fn onUnmapNotify(e: *c.XEvent) void {
    var ev = e.xunmap;
    warn("onUnmapNotify {}\n", ev.window);
    var screen = manager.getActiveScreen();
    var workspace = screen.getActiveWorkspace();
    wm.WorkspaceRemoveWindow(workspace, ev.window);
    stack(workspace, screen.info.width, screen.info.height);
}

pub fn stack(workspace: *wm.Workspace, width: u32, height: u32) void {
    if (workspace.amountOfWindows == 1) {
        resize(workspace.windows[0], 0, 0, width - 1, height);
    } else {
        for (workspace.windows[0..workspace.amountOfWindows]) |window, i| {
            var x: i32 = 0;
            var y: i32 = 0;
            var w = @divFloor(width, 2) - 1;
            var h = height;

            if (i > 0) {
                x = @divFloor(@intCast(i32, width), 2);
                var divisor: u32 = workspace.amountOfWindows - 1;
                h = @divTrunc(height, divisor);
                y = @intCast(i32, (h * (i - 1)));
            }

            warn("{} {} {} {}\n", x, y, w, h);
            resize(window, x, y, w, h);
        }
    }
}

pub fn onMapRequest(e: *c.XEvent) void {
    var ev = e.xmap;
    warn("map request {}\n", ev.window);

    var screen = manager.getActiveScreen();
    var workspace = screen.getActiveWorkspace();
    wm.WorkspaceAddWindow(workspace, ev.window);
    // TODO: check if window actually in workspace
    stack(workspace, screen.info.width, screen.info.height - bar.height);
    _ = c.XSelectInput(xlib.display, ev.window, c.EnterWindowMask | c.FocusChangeMask);
    _ = c.XMapWindow(xlib.display, ev.window);
    _ = c.XSync(xlib.display, 1);
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

pub fn resize(window: c.Window, x: i32, y: i32, width: u32, height: u32) void {
    var changes: c.XWindowChanges = undefined;
    changes.x = x;
    changes.y = y;
    changes.width = @intCast(c_int, width);
    changes.height = @intCast(c_int, height);
    warn("resize {}\n", window);
    _ = c.XConfigureWindow(xlib.display, window, c.CWX | c.CWY | c.CWWidth | c.CWHeight, &changes);
}



pub fn drawBar() void {
    var screen = manager.getActiveScreen();

    var buttonSize: u32 = 16;
    for (screen.workspaces) |workspace, i| {
        var color = config.COLOR.FOREGROUND_NOFOCUS;
        if (i == screen.activeWorkspace) {
            color = config.COLOR.FOREGROUND_FOCUS;
        }
        xlib.setForegroundColor(bar.gc, @enumToInt(color));

        var mul = @intCast(u32, i);
        bar.fillRect(@intCast(i32, buttonSize * mul) + 1, 1, buttonSize - 2, buttonSize - 2);
        bar.render();
    }
}

fn onExpose(e: *c.XEvent) void {
    warn("on expose\n");
    drawBar();
}

fn onFocusIn(e: *c.XEvent) void {
    var ev = e.xfocus;
}

fn xineramaGetScreenInfo() void {
    var isActive = c.XineramaIsActive(xlib.display);
    std.debug.assert(isActive == 1);

    // Parse screen info
    var screenInfo: [*]c.XineramaScreenInfo = undefined;
    var numScreens: c_int = 0;
    screenInfo = c.XineramaQueryScreens(xlib.display, &numScreens);

    {
        var i: u32 = 0;
        while (i < @intCast(u32, numScreens)) : (i += 1) {
            warn("info {}\n", screenInfo[i]);
            manager.screens[i].info.x = @intCast(i32, screenInfo[i].x_org);
            manager.screens[i].info.y = @intCast(i32, screenInfo[i].y_org);
            manager.screens[i].info.width = @intCast(u32, screenInfo[i].width);
            manager.screens[i].info.height = @intCast(u32, screenInfo[i].height);
        }
    }
}

pub fn main() void {
    xlib.init();
    defer xlib.init();

    xlib.grabKey(c.Mod4Mask, c.XK_p);
    xlib.grabKey(c.Mod4Mask, c.XK_k);
    xlib.grabKey(c.Mod4Mask, c.XK_1);
    xlib.grabKey(c.Mod4Mask, c.XK_2);

    for (config.keys) |key| {
        xlib.grabKey(key.modifier, key.keysym);
    }

    for (config.colors) |color, i| {
        xlib.addColor(i, color[0], color[1], color[2]);
    }

    xineramaGetScreenInfo();

    var screen = manager.getActiveScreen();

    var barheight: u32 = 16;
    bar = xdraw.DrawableWindow{
        .x = 0,
        .y = @intCast(i32, screen.info.height - barheight - 1),
        .height = barheight,
        .width = screen.info.width,
    };
    bar.init(xlib.display, xlib.root, xlib.screen);

    defer bar.delete();

    manager.running = true;
    warn("root is {}\n", xlib.root);

    while (manager.running) {
        var e: c.XEvent = undefined;
        _ = c.XNextEvent(xlib.display, &e);

        // TODO: maybe pass active screen and workspace to event handling methods
        switch (e.type) {
            c.Expose => onExpose(&e),
            c.KeyPress => {
                var ev = e.xkey;
                var keysym = c.XKeycodeToKeysym(xlib.display, @intCast(u8, ev.keycode), 0);
                var workspace = screen.getActiveWorkspace();

                for (config.keys) |key| {
                    if (ev.state == key.modifier and keysym == key.keysym) {
                        key.action(key.arg);
                        break;
                    }
                }

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
            c.FocusIn => onFocusIn(&e),
            c.NoExpose => warn("NoExpose\n"),
            else => warn("not handled {}\n", e.type),
        }
    }
}
