const config = @import("config.zig");
const c = @import("c.zig");
const X = @import("x.zig");
const std = @import("std");
const wm = @import("wm.zig");
const colors = @import("colors.zig");
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
var colours: colors.Colors = undefined;
pub var layouts: [wm.maxWindows]layouter.Layout = undefined;


fn getBar(index: usize) c.Window {
    return bars[index];
}

pub fn onConfigureRequest(e: *c.XEvent) void {
    var event = e.xconfigurerequest;
    warn("------------------\n");
    warn("Configure Request {}\n", event.window);
    var workspace = manager.getActiveScreen().getActiveWorkspace();
    if (!workspace.hasWindow(event.window)) {
        warn("Window is not registered\n");
        var changes: c.XWindowChanges = undefined;
        changes.height = e.xconfigurerequest.height;
        changes.border_width = e.xconfigurerequest.border_width;
        changes.sibling = e.xconfigurerequest.above;
        changes.stack_mode = e.xconfigurerequest.detail;
        _ = c.XConfigureWindow(xlib.display, event.window, @intCast(c_uint, event.value_mask), &changes);
    } else {
        warn("Window is already registered\n");
    }
}

pub fn onDestroyNotify(e: *c.XEvent) void {
    var event = e.xdestroywindow;
    var screen = manager.getActiveScreen();
    var workspace = screen.getActiveWorkspace();
    workspace.removeWindow(event.window);
}

pub fn windowFocus(window: u64) void {
    var screen = manager.getActiveScreen();
    var workspace = screen.getActiveWorkspace();
    var index = workspace.getWindowIndex(window);
    warn("index is {}\n", index);
    if (index >= 0) {
        var oldFocus = workspace.getFocusedWindow();
        workspace.focusedWindow = @intCast(u32, index);
        var newFocus = workspace.getFocusedWindow();
        xlib.focusWindow(newFocus);

        xlib.windowSetBorder(oldFocus, getColor(config.COLOR.BLACK), config.borderWidth);
        xlib.windowSetBorder(newFocus, getColor(config.COLOR.FOREGROUND_FOCUS_FG), config.borderWidth);
        drawBar();
    }
}

fn onEnterNotify(e: *c.XEvent) void {
    var event = e.xcrossing;
    warn("Enter Notify ---- {} ---- {}\n", event.window, manager.activeScreenIndex);
    var buffer: [256]u8 = undefined;

    notifyf("Got a window {}", event.window);

    if (event.window != xlib.root and !config.focusOnClick) {
        var screenIndex = manager.getScreenIndexOfWindow(event.window);
        manager.activeScreenIndex = @intCast(u32, screenIndex);
        warn("EnterNotify ScreenSelect {}", manager.activeScreenIndex);
        windowFocus(event.window);
        drawBar();
    }
}

fn onUnmapNotify(e: *c.XEvent) void {
    var event = e.xunmap;
    var screen = manager.getActiveScreen();
    var workspace = screen.getActiveWorkspace();
    var newFocusIndex = workspace.getWindowIndex(event.window) - 1;
    if (newFocusIndex < 0) {
        newFocusIndex = 0;
    }
    workspace.removeWindow(event.window);
    layouts[manager.activeScreenIndex].stack(workspace, &xlib);
    workspace.focusedWindow = @intCast(u32, newFocusIndex);
    if (workspace.amountOfWindows > 0) {
        windowFocus(workspace.getFocusedWindow());
    }
    // TODO: ungabButtons???
}


fn getColor(color: config.COLOR) u64 {
    return colours.getColorPixel(@enumToInt(color));
}

pub fn onMapRequest(e: *c.XEvent) void {
    var event = e.xmap;
    warn("Map Request ---- {} ---- {}\n", event.window, manager.activeScreenIndex);
    notifyf("Map Request {}\n", manager.activeScreenIndex);

    var screen = manager.getActiveScreen();
    var workspace = screen.getActiveWorkspace();
    if (workspace.addWindow(event.window)) {
        layouts[manager.activeScreenIndex].stack(workspace, &xlib);
        _ = c.XSelectInput(xlib.display, event.window, c.EnterWindowMask | c.FocusChangeMask);
        _ = c.XMapWindow(xlib.display, event.window);
        _ = c.XSync(xlib.display, 1);
        windowFocus(event.window);
        xlib.grabButton(event.window);
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
}


pub fn half(value: u32) i32 {
    return @intCast(i32, @divFloor(value, 2));
}


pub fn drawBar() void {


    for (manager.screens[0..manager.amountScreens]) |*screen, screenIndex| {

        var bar = getBar(screenIndex);
        var bardraw = &barDraws[screenIndex];
        var w = xlib.getWindowWidth(bar);
        var barheight = xlib.getWindowHeight(bar);
        var barwidth = xlib.getWindowWidth(bar);

        var backgroundColor = config.COLOR.BACKGROUND;
        bardraw.setForeground(getColor(backgroundColor));

        bardraw.fillRect(0, 0, w, barheight);

        if (screenIndex == manager.activeScreenIndex) {
            bardraw.setForeground(getColor(config.COLOR.FOREGROUND_FOCUS_FG));
            var focusbarWidth: u32 = 200;
            var focusbarHeight: u32 = 4;
            bardraw.fillRect(half(barwidth) - half(focusbarWidth), @intCast(i32, barheight - focusbarHeight), focusbarWidth, focusbarHeight);
        }



        // TODO: get height of font
        var buttonSize: u32 = barheight - 2;
        for (screen.workspaces) |workspace, i| {

            var focus = i == screen.activeWorkspace;
            var mul = @intCast(u32, i);
            var color = config.COLOR.FOREGROUND_NOFOCUS;

            if (focus) {
                color = config.COLOR.FOREGROUND_FOCUS_BG;
            }
            
            var x = @intCast(i32, buttonSize * mul) + 1;

            bardraw.setForeground(getColor(color));
            bardraw.fillRect(x, 1, buttonSize - 2, buttonSize - 2);

            if (focus) {
                color = config.COLOR.FOREGROUND_FOCUS_FG;
                bardraw.setForeground(getColor(color));
                bardraw.fillRect(x, @intCast(i32, barheight) - 4, buttonSize - 2, buttonSize - 2);


            }

        }
        var workspace = screen.getActiveWorkspace();
        bardraw.render();

        if (workspace.amountOfWindows > 0) {
            // TODO: usize
            var window = workspace.getFocusedWindow();
            var prop: c.XTextProperty = undefined;
            if (xlib.getWindowName(window, &prop)) {
                var name: [256]u8 = undefined;
                @memcpy(&name, prop.value, prop.nitems);
                defer xlib.freeWindowName(&prop);

                var width: u32 = 0;
                var height: u32 = 0;
                bardraw.getTextDimensions(xlib.font, name[0..prop.nitems], &width, &height);
                var x = half(w) - half(width);
                var y: i32 = 0;
                // TODO: bardraw.render overwrites drawtext
                bardraw.drawText(xlib.font, colours.getColor(@enumToInt(config.COLOR.FOREGROUND_FOCUS_FG)),
                                 x, y, name[0..prop.nitems]);
            } else {
                std.debug.warn("not able to get window name\n");
            }


        }
    }

}

fn onExpose(e: *c.XEvent) void {
    drawBar();
}

fn onNoExpose(e: *c.XEvent) void {
    //drawBar();
}

fn onMotionNotify(e: *c.XEvent) void {
    var event = e.xmotion;
    for (manager.screens[0..manager.amountScreens]) |screen, screenIndex| {
        if (event.x_root > screen.info.x and event.x_root < screen.info.x + @intCast(i32, screen.info.width)
            and event.y_root > screen.info.y and event.y_root < screen.info.y + @intCast(i32, screen.info.height)) {

            if (manager.activeScreenIndex != screenIndex) {
                notifyf("Motion ScreenSelect {}", manager.activeScreenIndex);
                notifyf("Motion ScreenSelect {}", event.x_root);
                manager.activeScreenIndex = screenIndex;
                drawBar();
            }
        }
    }
}

fn onKeyPress(e: *c.XEvent) void {
    var event = e.xkey;
    var keysym = c.XKeycodeToKeysym(xlib.display, @intCast(u8, event.keycode), 0);
    var screen = manager.getActiveScreen();
    var workspace = screen.getActiveWorkspace();

    for (config.keys) |key| {
        if (event.state == key.modifier and keysym == key.keysym) {
            key.action(key.arg);
            break;
        }
    }
}

fn onButtonPress(e: *c.XEvent) void {
    var event = e.xbutton;
    _ = c.XAllowEvents(xlib.display, c.ReplayPointer, c.CurrentTime);
    windowFocus(event.window);

}

fn notify(msg: []const u8, window: u64) void {
    var buffer: [256]u8 = undefined;
    var str = std.fmt.bufPrint(&buffer, "{} {}", msg, window) catch unreachable;
    commands.notify(config.Arg{.String=str});
}

pub fn notifyf(comptime msg: []const u8, args: ...) void {
    var buffer: [256]u8 = undefined;
    var str = std.fmt.bufPrint(&buffer, msg, args) catch unreachable;
    //commands.notify(config.Arg{.String=str});
}

fn onFocusIn(e: *c.XEvent) void {
    var event = e.xfocus;
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
            manager.screens[i].info.x = @intCast(i32, screenInfo[i].x_org);
            manager.screens[i].info.y = @intCast(i32, screenInfo[i].y_org);
            manager.screens[i].info.width = @intCast(u32, screenInfo[i].width);
            manager.screens[i].info.height = @intCast(u32, screenInfo[i].height);
            manager.amountScreens = i + 1;
        }
    }


}

pub fn main() void {
    xlib.init(config.fontname);
    defer xlib.delete();

    for (config.keys) |key| {
        xlib.grabKey(key.modifier, key.keysym);
    }

    xineramaGetScreenInfo();

    colours.init(xlib.display, xlib.screen);
    for (config.colors) |color, i| {
        colours.addColor(xlib.display, i, color[0], color[1], color[2]);
    }

    for (manager.screens[0..manager.amountScreens]) |*screen, screenIndex| {
        var barheight: u32 = 32;
        var barwidth: u32 = screen.info.width;
        var bardraw = &barDraws[screenIndex];

        var x = screen.info.x;
        var y = @intCast(i32, screen.info.height - barheight - 1);
        bars[screenIndex] = xlib.createWindow(x, y + 1, barwidth, barheight);
        bardraw.init(xlib.display, bars[screenIndex], xlib.screen, barwidth, barheight);

        layouts[screenIndex].x = screen.info.x;
        layouts[screenIndex].y = screen.info.y;
        layouts[screenIndex].width = screen.info.width;
        layouts[screenIndex].height= screen.info.height - barheight;
    }


    var cmd = "cd ~/.uwm; ./autostart.sh &";
    _ = c.system(&cmd);
    manager.running = true;


    while (manager.running) {
        var e: c.XEvent = undefined;
        _ = c.XNextEvent(xlib.display, &e);

        switch (e.type) {
            c.Expose => onExpose(&e),
            c.KeyPress => onKeyPress(&e),
            c.ConfigureRequest => onConfigureRequest(&e),
            c.MapRequest => onMapRequest(&e),
            c.UnmapNotify => onUnmapNotify(&e),
            c.DestroyNotify => onDestroyNotify(&e),
            c.EnterNotify => onEnterNotify(&e),
            c.FocusIn => onFocusIn(&e),
            c.NoExpose => onNoExpose(&e),
            c.MotionNotify => onMotionNotify(&e),
            c.ButtonPress => onButtonPress(&e),
            else => continue,
            //else => warn("not handled {}\n", e.type),
        }
    }

    for (barDraws) |*bardraw| {
        bardraw.free();
    }

}
