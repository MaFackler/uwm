const config = @import("config.zig");
const c = @import("c.zig");
const X = @import("x.zig");
const std = @import("std");
const wm = @import("wm.zig");
const commands = @import("commands.zig");
const xdraw = @import("xdraw.zig");
const layouter = @import("layouter.zig");
const warn = std.debug.warn;
const panic = std.debug.panic;

const Allocator = std.mem.Allocator;
pub var xlib = X.Xlib{};

// TODO: maybe dynamic arrays
pub var manager: wm.WindowManager = wm.WindowManager{};

var bars: [wm.maxWindows]c.Window = undefined;
var barDraws: [wm.maxWindows]xdraw.Draw = undefined;
pub var layouts: [wm.maxWindows]layouter.Layout = undefined;

//var windows = std.AutoHashMap(u64, Workspace).init(std.heap.direct_allocator);


fn getBar(index: usize) c.Window {
    return bars[index];
}

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
    commands.notify(config.Arg{.String="Destroy Notify"});
    var ev = e.xdestroywindow;
    var screen = manager.getActiveScreen();
    var workspace = screen.getActiveWorkspace();
    workspace.removeWindow(ev.window);
}

fn onEnterNotify(e: *c.XEvent) void {
    var ev = e.xcrossing;
    notify("Enter Notify", ev.window);
    var buffer: [256]u8 = undefined;
    var err = std.fmt.bufPrint(&buffer, "{} {}", "Enter Notify", ev.window);
    commands.notify(config.Arg{.String=buffer});
    var screen = manager.getActiveScreen();
    var workspace = screen.getActiveWorkspace();
    var index = workspace.getWindowIndex(ev.window);
    if (index >= 0) {
        workspace.focusedWindow = @intCast(u32, index);
    }
    drawBar();
}

fn onUnmapNotify(e: *c.XEvent) void {
    var ev = e.xunmap;
    var screen = manager.getActiveScreen();
    var workspace = screen.getActiveWorkspace();
    workspace.removeWindow(ev.window);
    layouts[manager.activeScreenIndex].stack(workspace, &xlib);
}


pub fn onMapRequest(e: *c.XEvent) void {
    var ev = e.xmap;
    warn("map request {}\n", ev.window);

    var screen = manager.getActiveScreen();
    var workspace = screen.getActiveWorkspace();
    if (workspace.addWindow(ev.window)) {
        layouts[manager.activeScreenIndex].stack(workspace, &xlib);
        _ = c.XSelectInput(xlib.display, ev.window, c.EnterWindowMask | c.FocusChangeMask);
        _ = c.XMapWindow(xlib.display, ev.window);
        _ = c.XSync(xlib.display, 1);
        drawBar();
    }
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




pub fn drawBar() void {


    for (manager.screens[0..manager.amountScreens]) |*screen, screenIndex| {

        var bar = getBar(screenIndex);
        var bardraw = &barDraws[screenIndex];
        var w = xlib.getWindowWidth(bar);
        var barheight = xlib.getWindowHeight(bar);

        var backgroundColor = config.COLOR.BACKGROUND;
        if (screenIndex == manager.activeScreenIndex) {
            backgroundColor = config.COLOR.FOREGROUND_FOCUS;
        }
        bardraw.setColor(@enumToInt(backgroundColor));

        bardraw.fillRect(0, 0, w, barheight);
        // TODO: get height of font
        var buttonSize: u32 = 16;
        for (screen.workspaces) |workspace, i| {
            var color = config.COLOR.FOREGROUND_NOFOCUS;
            if (i == screen.activeWorkspace) {
                color = config.COLOR.FOREGROUND_FOCUS;
            }
            bardraw.setColor(@enumToInt(color));

            var mul = @intCast(u32, i);
            bardraw.fillRect(@intCast(i32, buttonSize * mul) + 1, 1, buttonSize - 2, buttonSize - 2);
            bardraw.render();
        }
        var workspace = screen.getActiveWorkspace();

        if (workspace.amountOfWindows > 0) {
            // TODO: usize
            var window = workspace.windows[@intCast(u32, workspace.focusedWindow)];
            var prop: c.XTextProperty = undefined;
            xlib.getWindowName(window, &prop);
            var name: [256]u8 = undefined;
            warn("prop is {}\n", prop);
            @memcpy(&name, prop.value, prop.nitems);
            warn("window name is {s}\n", name);
            defer xlib.freeWindowName(&prop);

            bardraw.drawText(xlib.font, @intCast(i32, @divFloor(w, 2)) - 20, xlib.font.ascent + 1, name[0..prop.nitems]);
        }
    }

}

fn onExpose(e: *c.XEvent) void {
    warn("on expose\n");
    drawBar();
}

fn onNoExpose(e: *c.XEvent) void {
    //warn("on noexpose\n");
    //drawBar();
}

fn notify(msg: []const u8, window: u64) void {
    var buffer: [256]u8 = undefined;
    var str = std.fmt.bufPrint(&buffer, "{} {}", msg, window) catch unreachable;
    commands.notify(config.Arg{.String=str});
}

fn onFocusIn(e: *c.XEvent) void {
    var ev = e.xfocus;
    notify("Focus In", ev.window);
    //commands.notify(config.Arg{.String="Focus In"});
    //var ev = e.xfocus;
    //var w = manager.getActiveScreen().getActiveWorkspace();
    //if (ev.window != w.getFocusedWindow()) {
    //    for (manager.screens[0..manager.amountScreens]) |*screen, screenIndex| {
    //        var workspace = screen.getActiveWorkspace();
    //        var index = workspace.getWindowIndex(ev.window);
    //        if (index >= 0) {
    //            workspace.focusedWindow = @intCast(u32, index);
    //            manager.activeScreenIndex = @intCast(u32, screenIndex);
    //            break;
    //        }
    //    }
    //}
    //drawBar();
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
            manager.amountScreens = i + 1;
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


    xineramaGetScreenInfo();

    warn("Amount of screens {}\n", manager.amountScreens);


    for (manager.screens[0..manager.amountScreens]) |*screen, screenIndex| {
        var barheight: u32 = 16;
        var barwidth: u32 = screen.info.width;
        var bardraw = &barDraws[screenIndex];

        var x = screen.info.x;
        var y = @intCast(i32, screen.info.height - barheight - 1);
        bars[screenIndex] = xlib.createWindow(x, y, barwidth, barheight);
        bardraw.init(xlib.display, bars[screenIndex], xlib.screen, barwidth, barheight);

        for (config.colors) |color, i| {
            bardraw.addColor(i, color[0], color[1], color[2]);
        }
        layouts[screenIndex].width = screen.info.width;
        layouts[screenIndex].height= screen.info.height - barheight;
    }


    var cmd = "cd ~/.uwm; ./autostart.sh &";
    _ = c.system(&cmd);
    manager.running = true;
    warn("root is {}\n", xlib.root);


    while (manager.running) {
        var e: c.XEvent = undefined;
        _ = c.XNextEvent(xlib.display, &e);

        switch (e.type) {
            c.Expose => onExpose(&e),
            c.KeyPress => {
                var ev = e.xkey;
                var keysym = c.XKeycodeToKeysym(xlib.display, @intCast(u8, ev.keycode), 0);
                var screen = manager.getActiveScreen();
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
            c.NoExpose => onNoExpose(&e),
            else => warn("not handled {}\n", e.type),
        }
    }

    for (barDraws) |*bardraw| {
        bardraw.free();
    }

}
