const std = @import("std");
const c = @import("c.zig");
const commands = @import("commands.zig");

const ActionFunc = fn(comptime arg: i32) void;

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

pub const COLOR = enum(u2) {
    FOREGROUND_FOCUS,
    FOREGROUND_NOFOCUS,
    BACKGROUND,
    AMOUNT,
};
pub const COLOR_AMOUNT = @enumToInt(COLOR.AMOUNT);

pub const colors = [COLOR_AMOUNT][3]u8{
    [_]u8{ 255, 0, 0 },
    [_]u8{ 11, 11, 11 },
    [_]u8{ 0, 0, 0 },
};

pub var keys = [_]KeyDef{
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_q, .action = commands.windowClose, .arg = undefined},
    KeyDef{ .modifier = c.Mod4Mask | c.ShiftMask, .keysym = c.XK_q, .action = commands.exit, .arg = undefined},

    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_1, .action = commands.workspaceShow, .arg = Arg{.UInt=0}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_2, .action = commands.workspaceShow, .arg = Arg{.UInt=1}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_3, .action = commands.workspaceShow, .arg = Arg{.UInt=2}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_4, .action = commands.workspaceShow, .arg = Arg{.UInt=3}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_5, .action = commands.workspaceShow, .arg = Arg{.UInt=4}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_6, .action = commands.workspaceShow, .arg = Arg{.UInt=5}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_7, .action = commands.workspaceShow, .arg = Arg{.UInt=6}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_8, .action = commands.workspaceShow, .arg = Arg{.UInt=7}},

    // TODO: use environment variables for term, browser, launcher
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_p, .action = commands.run, .arg = Arg{.StringList=[_][]const u8{"rofi", "-show", "run"}}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_Return, .action = commands.run, .arg = Arg{.StringList=[_][]const u8{"alacritty"}}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_b, .action = commands.run, .arg = Arg{.StringList=[_][]const u8{"chromium"}}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_m, .action = commands.run, .arg = Arg{.StringList=[_][]const u8{"notify-send", "-t", "200", "test message"}}},
    KeyDef{ .modifier = c.Mod4Mask, .keysym = c.XK_n, .action = commands.notify, .arg = Arg{.String="Test Message"}},
};
