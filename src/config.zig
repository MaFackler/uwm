const std = @import("std");
const c = @import("c.zig");
const commands = @import("commands.zig");

const ActionFunc = fn(comptime arg: i32) void;

pub const fontname = "Ubuntu-14";

pub const Arg = union {
    Int: i32,
    UInt: u32,
    float: f32,
    StringList: [][]const u8,
    String: []const u8,
};

const Action = struct {
    func: fn(arg: Arg) void,
};


const KeyDef = struct {
    modifier: u32,
    keysym: c.KeySym,
    action: fn(arg: Arg) void,
    arg: Arg,
};

pub const COLOR = enum(u8) {
    FOREGROUND_FOCUS_BG,
    FOREGROUND_FOCUS_FG,
    FOREGROUND_NOFOCUS,
    BACKGROUND,
    BLACK,
    WHITE,
    AMOUNT,
};
pub const COLOR_AMOUNT = @enumToInt(COLOR.AMOUNT);

pub const colors = [COLOR_AMOUNT][3]u8{
    [_]u8{ 66, 50, 44 },
    [_]u8{ 245, 108, 66 },
    [_]u8{ 22, 22, 22 },
    [_]u8{ 0, 0, 0 },
    [_]u8{ 0, 0, 0 },
    [_]u8{ 255, 255, 255 },
};

pub var gapsize: u32 = 8;
pub var borderWidth: i32 = 2;
pub var focusOnClick: bool = true;

pub var keys = [_]KeyDef{
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_q, .action = commands.windowClose, .arg = undefined},
    KeyDef{ .modifier = c.Mod4Mask | c.ShiftMask, .keysym = c.XK_e, .action = commands.exit, .arg = undefined},

    // Window Management
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_j, .action = commands.windowPrevious, .arg = Arg{.UInt=0}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_k, .action = commands.windowNext, .arg = Arg{.UInt=0}},

    // Workspace Management
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_1, .action = commands.workspaceShow, .arg = Arg{.UInt=0}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_2, .action = commands.workspaceShow, .arg = Arg{.UInt=1}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_3, .action = commands.workspaceShow, .arg = Arg{.UInt=2}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_4, .action = commands.workspaceShow, .arg = Arg{.UInt=3}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_5, .action = commands.workspaceShow, .arg = Arg{.UInt=4}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_6, .action = commands.workspaceShow, .arg = Arg{.UInt=5}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_7, .action = commands.workspaceShow, .arg = Arg{.UInt=6}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_8, .action = commands.workspaceShow, .arg = Arg{.UInt=7}},

    // Screen selection
    // TODO: my motior order is swapped
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_period, .action = commands.screenSelectByDelta, .arg = Arg{.Int=-1}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_comma, .action = commands.screenSelectByDelta, .arg = Arg{.Int=1}},

    // Applications
    // TODO: use environment variables for term, browser, launcher
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_p, .action = commands.run, .arg = Arg{.StringList=[_][]const u8{"rofi", "-show", "run"}}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_Return, .action = commands.run, .arg = Arg{.StringList=[_][]const u8{"alacritty"}}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_b, .action = commands.run, .arg = Arg{.StringList=[_][]const u8{"chromium"}}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_m, .action = commands.run, .arg = Arg{.StringList=[_][]const u8{"notify-send", "-t", "200", "test message"}}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_n, .action = commands.notify, .arg = Arg{.String="Test Message"}},
};
