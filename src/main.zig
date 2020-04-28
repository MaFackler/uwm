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

var msgQueue = std.atomic.Queue(i32).init();

var timestring: [16]u8 = undefined;

// TODO: maybe dynamic arrays
pub var manager: wm.WindowManager = wm.WindowManager{};

var bars: [wm.maxWindows]c.Window = undefined;
var barDraws: [wm.maxWindows]xdraw.Draw = undefined;
var colours: colors.Colors = undefined;
pub var layouts: [wm.maxWindows]layouter.Layout = undefined;

var logfile: std.fs.File = undefined;

fn getBar(index: usize) c.Window {
    return bars[index];
}

pub fn onConfigureRequest(e: *c.XEvent) void {
    var event = e.xconfigurerequest;
    var screen = manager.getActiveScreen();
    var workspace = screen.getActiveWorkspace();
    var changes: c.XWindowChanges = undefined;
    if (!workspace.hasWindow(event.window)) {
        changes.x = event.x;
        changes.y = event.y;
        changes.width = event.width;
        changes.height = event.height;
        changes.border_width = event.border_width;
        changes.sibling = event.above;
        changes.stack_mode = event.detail;
        _ = c.XConfigureWindow(xlib.display, event.window, @intCast(c_uint, event.value_mask), &changes);
        _ = c.XSync(xlib.display, 0);
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
    if (index >= 0) {
        debug("WINDOW FOCUS {}: {}\n", .{ @as(usize, manager.activeScreenIndex), @as(i32, index)});
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
    debug("on enter notify {}\n", .{@as(u64, event.window)});
    var buffer: [256]u8 = undefined;

    if (event.window != xlib.root) {
        var screenIndex = manager.getScreenIndexOfWindow(event.window);
        manager.activeScreenIndex = @intCast(u32, screenIndex);
        debug("onEnterNotify window focus\n", .{});

        if (!config.focusOnClick) {
            windowFocus(event.window);
        }
        drawBar();
    }
}

fn debug(comptime msg: []const u8, args: var) void {
    //var buf: [256]u8 = undefined;
    //var str = std.fmt.bufPrint(&buf, msg, args) catch unreachable;
    //var res = logfile.write(str) catch unreachable;
    std.debug.warn(msg, args);
}

fn onUnmapNotify(e: *c.XEvent) void {
    var event = e.xunmap;
    debug("onUnmapNotify {}\n", .{@as(u64, event.window)});
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
        debug("onUnmapNotify window focus {} {}\n", .{@as(u64, event.window), @as(u64, workspace.getFocusedWindow())});
        //windowFocus(workspace.getFocusedWindow());
    }
    //xlib.ungrabButton(event.window);
}


fn getColor(color: config.COLOR) u64 {
    return colours.getColorPixel(@enumToInt(color));
}


pub fn onMapRequest(e: *c.XEvent) void {
    var event = e.xmap;
    var screen = manager.getActiveScreen();
    var workspace = screen.getActiveWorkspace();
    debug("onMapRequest {}\n", .{@as(u64, event.window)});
    debug("override_redirect is {}\n", .{@as(i32, event.override_redirect)});

    xlib.grabButton(event.window);
    var fixed = xlib.isFixed(event.window);
    // NOTE: popups or application like steam will request a fixed size and will not be
    // manged by window manager
    if (fixed) {
        _ = c.XMapWindow(xlib.display, event.window);
    } else if (workspace.addWindow(event.window)) {
        layouts[manager.activeScreenIndex].stack(workspace, &xlib);
        _ = c.XSelectInput(xlib.display, event.window, c.EnterWindowMask | c.FocusChangeMask | c.PointerMotionMask);
        _ = c.XMapWindow(xlib.display, event.window);
        windowFocus(event.window);
    }

    _ = c.XSync(xlib.display, 0);
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
            }

        }

        var textWidth: u32 = 0;
        var textHeith: u32 = 0;
        bardraw.getTextDimensions(xlib.font, &timestring, &textWidth, &textHeith);
        bardraw.drawText(xlib.font, colours.getColor(@enumToInt(config.COLOR.FOREGROUND_FOCUS_FG)),
                         @intCast(i32, barwidth - textWidth - 10), 5, timestring[0..timestring.len]);
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
    var workspace = manager.getActiveScreen().getActiveWorkspace();
    // TODO: issue when to many motion events?? it laggs
    //debug("Motion Event {}\n", .{ @as(u64, event.window)});

    if (!workspace.hasWindow(event.window)) {
        xlib.move(event.window, 200, 200);
    }
    for (manager.screens[0..manager.amountScreens]) |screen, screenIndex| {
        if (event.x_root > screen.info.x and event.x_root < screen.info.x + @intCast(i32, screen.info.width)
            and event.y_root > screen.info.y and event.y_root < screen.info.y + @intCast(i32, screen.info.height)) {

            if (manager.activeScreenIndex != screenIndex) {
                debug("Motion ScreenSelect {}\n", .{ @as(usize, manager.activeScreenIndex)});
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
        if (event.state == key.modifier and keysym == key.code) {
            key.action(event.window, key.arg);
            break;
        }
    }
}


fn onButtonPress(e: *c.XEvent) void {
    var event = e.xbutton;
    debug("window click {}\n", .{event.window});

    for (config.buttons) |button| {
        if (event.state == button.modifier and event.button == button.code) {
            button.action(event.window, button.arg);
            break;
        }
    }
    
    _ = c.XAllowEvents(xlib.display, c.ReplayPointer, c.CurrentTime);
    windowFocus(event.window);

}

fn notify(msg: []const u8, window: u64) void {
    var buffer: [256]u8 = undefined;
    var str = std.fmt.bufPrint(&buffer, "{} {}", msg, window) catch unreachable;
    commands.notify(config.Arg{.String=str});
}

pub fn notifyf(comptime msg: []const u8, args: var) void {
    //var buffer: [256]u8 = undefined;
    //var str = std.fmt.bufPrint(&buffer, msg, args) catch unreachable;
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

const ThreadCtx = struct {
    display: *c.Display,
    window: u64,
};

fn updateStatusbar(ctx: *ThreadCtx) u8 {
    var counter: u32 = 0;
    while (manager.running) {
        //c.XLockDisplay(ctx.display);
        var seconds = std.time.milliTimestamp() / 1000;
        comptime const secondsPerDay = 24 * 60 * 60;
        var days = seconds / secondsPerDay;
        var years = days / 365;
        var d = Date{};
        d.localtime();
        var str = std.fmt.bufPrint(&timestring, "{d:0<4}-{d:0<2}-{d:0<2} {d:0<2}:{d:0<2}",
                                   .{d.year, d.month, d.day, d.hour, d.minute}) catch unreachable;

        //var event: c.XClientMessageEvent = undefined;
        //event.type = c.ClientMessage;
        //event.serial = 0;
        //event.send_event = 1;
        //event.message_type = c.XInternAtom(ctx.display, &"_APP_EVT", 0);
        //event.format = 32;
        //event.window = ctx.window;
        //event.data.l[0] = @intCast(i64, c.XInternAtom(ctx.display, &"DUDE", 0));
        //event.data.l[1] = c.CurrentTime;
        ////event.send_event = 1;

        //_ = c.XSendEvent(ctx.display, ctx.window, 0, c.NoEventMask, @ptrCast(*c.XEvent, &event));
        ////_ = c.XSync(ctx.display, 0);
        //std.debug.warn("SEND EVENT\n");
        //c.XUnlockDisplay(ctx.display);

        var node = std.atomic.Queue(i32).Node{
            .data = 0,
            .next = undefined,
            .prev = undefined,
        };
        msgQueue.put(&node);
        std.time.sleep(1000000000);
        counter += 1;
    }
    return 0;
}

const Date = struct {
    year: u32 = 0,
    month: u32 = 0,
    day: u32 = 0,
    hour: u32 = 0,
    minute: u32 = 0,
    second: u32 = 0,

    fn localtime(self: *Date) void {
        var raw: c.time_t = undefined;
        _ = c.time(&raw);
        var info: *c.tm = c.localtime(&raw);
        self.year = @intCast(u32, info.tm_year + 1900);
        self.month = @intCast(u32, info.tm_mon + 1);
        self.day = @intCast(u32, info.tm_mday);
        self.hour = @intCast(u32, info.tm_hour);
        self.minute = @intCast(u32, info.tm_min);
        self.second = @intCast(u32, info.tm_sec);
    }
};

pub fn main() !void {
    
    logfile = std.fs.cwd().createFile("log.txt", .{}) catch unreachable;

    xlib.init(config.fontname);
    _ = c.XInitThreads();
    defer xlib.delete();

    for (config.keys) |key| {
        xlib.grabKey(key.modifier, key.code);
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


    var cmd: [*:0]const u8 = "cd ~/.config/.uwm; ./autostart.sh &";
    _ = c.system(cmd);
    manager.running = true;


    var ctx = ThreadCtx{.display=xlib.display, .window=xlib.root};

    var statusbarThread = try std.Thread.spawn(&ctx, updateStatusbar);
    while (manager.running) {

        var item = msgQueue.get();
        while (item != null) {
            drawBar();
            item = msgQueue.get();
        }

        if (c.XPending(xlib.display) > 0) {

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

        //// TODO: sleep correct way?
        std.time.sleep(1600000);
    }

    for (barDraws) |*bardraw| {
        bardraw.free();
    }

}
