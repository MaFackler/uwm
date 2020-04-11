const config = @import("config.zig");
const c = @import("c.zig");
const std = @import("std");
const wm = @import("wm.zig");
const xdraw = @import("xdraw.zig");
const warn = std.debug.warn;
const panic = std.debug.panic;
const linux = std.os.linux;

var display: ?*c.Display = undefined;
//var window: c.Window = undefined;
var root: c.Window = undefined;
const Allocator = std.mem.Allocator;

// TODO: maybe dynamic arrays
var activeScreenIndex: u32 = 0;
var displayWidth: i32 = 0;
var displayHeight: i32 = 0;
var screens: [8]wm.Screen = undefined;
var bar: xdraw.DrawableWindow = undefined;

//var windows = std.AutoHashMap(u64, Workspace).init(std.heap.direct_allocator);

// TODO: dynimaic size
var xColors: [config.COLOR_AMOUNT]c.XColor = undefined;

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

fn getActiveScreen() *wm.Screen {
    var res = &screens[activeScreenIndex];
    return res;
}

fn getActiveWorkspace() *wm.Workspace {
    var screen = getActiveScreen();
    return &screen.workspaces[screen.activeWorkspace];
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
    warn("onEnterNotify {}\n", ev.window);
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
    var screen = getActiveScreen();
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
    var workspace = getActiveWorkspace();
    var screen = getActiveScreen();
    wm.WorkspaceAddWindow(getActiveWorkspace(), ev.window);
    // TODO: check if window actually in workspace
    stack(workspace, screen.info.width, screen.info.height - bar.height);
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

pub fn resize(window: c.Window, x: i32, y: i32, width: u32, height: u32) void {
    var changes: c.XWindowChanges = undefined;
    changes.x = x;
    changes.y = y;
    changes.width = @intCast(c_int, width);
    changes.height = @intCast(c_int, height);
    warn("resize {}\n", window);
    _ = c.XConfigureWindow(display, window, c.CWX | c.CWY | c.CWWidth | c.CWHeight, &changes);
}

fn run(cmd: []const []const u8) !void {
    const rc = linux.fork();
    if (rc == 0) {
        var allocator = std.heap.direct_allocator;
        _ = try std.ChildProcess.exec(allocator, cmd, null, null, 2 * 1024);
        linux.exit(0);
    }
}

fn setForegroundColor(gc: c.GC, color: config.COLOR) void {
    _ = c.XSetForeground(display, bar.gc, xColors[@enumToInt(color)].pixel);
}

fn showTag(index: u32) void {
    var screen = getActiveScreen();
    var workspace = getActiveWorkspace();
    for (workspace.windows[0..workspace.amountOfWindows]) |window| {
        // TODO: better way to hide
        _ = c.XMoveWindow(display, window, -4000, 0);
    }
    screen.activeWorkspace = index;
    workspace = getActiveWorkspace();
    stack(workspace, screen.info.width, screen.info.height - bar.height);
    drawBar();
}

fn drawBar() void {
    var screen = getActiveScreen();
    // TODO: gc global?

    var buttonSize: u32 = 16;
    for (screen.workspaces) |workspace, i| {
        var color = config.COLOR.FOREGROUND_NOFOCUS;
        if (i == screen.activeWorkspace) {
            color = config.COLOR.FOREGROUND_FOCUS;
        }
        setForegroundColor(bar.gc, color);

        var mul = @intCast(u32, i);
        bar.fillRect(@intCast(i32, buttonSize * mul) + 1, 1, buttonSize - 2, buttonSize - 2);
        bar.render();
    }
}

fn onExpose(e: *c.XEvent) void {
    warn("on expose\n");
    drawBar();
}

extern fn errorHandler(d: ?*c.Display, e: [*c]c.XErrorEvent) c_int {
    warn("ERRRROR\n");
    return 0;
}

pub fn main() void {
    display = c.XOpenDisplay(null) orelse {
        panic("unable to create window");
    };

    defer {
        _ = c.XCloseDisplay(display);
    }

    var xscreen: i32 = 0;
    xscreen = c.XDefaultScreen(display);
    var bp: c_ulong = c.XBlackPixel(display, xscreen);
    var wp: c_ulong = c.XWhitePixel(display, xscreen);
    root = c.XRootWindow(display, xscreen);

    _ = c.XSetErrorHandler(errorHandler);
    var colormap = c.XDefaultColormap(display, xscreen);
    //_ = c.XAllocNamedColor(display, colormap, &"#FFFFFF", &colors[0], null);

    displayWidth = @intCast(i32, c.XDisplayWidth(display, xscreen));
    displayHeight = @intCast(i32, c.XDisplayHeight(display, xscreen));

    var windowAttributes: c.XSetWindowAttributes = undefined;
    windowAttributes.event_mask = c.SubstructureNotifyMask | c.SubstructureRedirectMask | c.KeyPressMask | c.EnterWindowMask | c.FocusChangeMask | c.PropertyChangeMask;
    _ = c.XSelectInput(display, root, windowAttributes.event_mask);

    _ = c.XSync(display, 0);
    var code = c.XKeysymToKeycode(display, c.XK_q);
    _ = c.XGrabKey(display, code, c.Mod4Mask, root, 1, c.GrabModeAsync, c.GrabModeAsync);
    code = c.XKeysymToKeycode(display, c.XK_p);
    _ = c.XGrabKey(display, code, c.Mod4Mask, root, 1, c.GrabModeAsync, c.GrabModeAsync);
    code = c.XKeysymToKeycode(display, c.XK_k);
    _ = c.XGrabKey(display, code, c.Mod4Mask, root, 1, c.GrabModeAsync, c.GrabModeAsync);

    code = c.XKeysymToKeycode(display, c.XK_1);
    _ = c.XGrabKey(display, code, c.Mod4Mask, root, 1, c.GrabModeAsync, c.GrabModeAsync);

    code = c.XKeysymToKeycode(display, c.XK_2);
    _ = c.XGrabKey(display, code, c.Mod4Mask, root, 1, c.GrabModeAsync, c.GrabModeAsync);

    _ = c.XineramaIsActive(display);

    // Parse screen info
    var screenInfo: [*]c.XineramaScreenInfo = undefined;
    var numScreens: c_int = 0;
    screenInfo = c.XineramaQueryScreens(display, &numScreens);

    {
        var i: u32 = 0;
        while (i < @intCast(u32, numScreens)) : (i += 1) {
            warn("info {}\n", screenInfo[i]);
            screens[i].info.x = @intCast(i32, screenInfo[i].x_org);
            screens[i].info.y = @intCast(i32, screenInfo[i].y_org);
            screens[i].info.width = @intCast(u32, screenInfo[i].width);
            screens[i].info.height = @intCast(u32, screenInfo[i].height);
        }
    }

    var screen = getActiveScreen();

    var barheight: u32 = 16;
    bar = xdraw.DrawableWindow{
        .x = 0,
        .y = @intCast(i32, screen.info.height - barheight - 1),
        .height = barheight,
        .width = screen.info.width,
    };
    bar.init(display.?, root, xscreen);
    defer bar.delete();

    for (config.colors) |color, i| {
        var xColor: *c.XColor = &xColors[i];
        xColor.red = color[0] * 255;
        xColor.green = color[1] * 255;
        xColor.blue = color[1] * 255;
        xColor.flags = c.DoRed | c.DoGreen | c.DoBlue;
        _ = c.XAllocColor(display, colormap, xColor);
        // TODO: why does AllocNamedColor not work
        //var name: []const u8 = "red\\0";
        //const name: []const u8 = "red";
        //const namePtr: [*]const u8 = name.ptr;
        //var res = c.XAllocNamedColor(display, colormap, namePtr, &color, &color);
    }

    var running = true;
    warn("root is {}\n", root);

    while (running) {
        var e: c.XEvent = undefined;
        _ = c.XNextEvent(display, &e);
        //_ = c.XFillRectangle(display, drawable, gc, 0, 0, 100, 100);

        warn("\nGOT event {}\n", e.type);

        switch (e.type) {
            c.Expose => onExpose(&e),
            c.KeyPress => {
                var ev = e.xkey;
                var keysym = c.XKeycodeToKeysym(display, @intCast(u8, ev.keycode), 0);
                warn("key event {}\n", ev);
                var workspace = getActiveWorkspace();

                if (ev.state == c.Mod4Mask) {
                    warn("keysym {} {}\n", ev.keycode, keysym);
                    if (keysym == c.XK_q) {
                        WindowClose(workspace.windows[@intCast(u32, workspace.focusedWindow)]);
                    } else if (keysym == c.XK_k) {
                        running = false;
                    } else if (keysym == c.XK_p) {
                        var err = run([_][]const u8{ "rofi", "-show", "run" });
                    } else if (keysym >= c.XK_1 and keysym <= c.XK_8) {
                        showTag(@intCast(u32, keysym - c.XK_1));
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
            c.FocusIn => warn("FocusIn\n"),
            c.NoExpose => warn("NoExpose\n"),
            else => warn("not handled {}\n", e.type),
        }

        //_ = c.XFillRectangle(display, drawable, gc, 20, 20, 100, 100);
        //_ = c.XCopyArea(display, drawable, root, gc, 0, 0, 800, 600, 0, 0);
        //_ = c.XFlush(display);
        _ = c.XSync(display, 0);
        warn("End loop\n");
    }
}
