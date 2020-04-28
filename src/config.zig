const std = @import("std");
const c = @import("c.zig");
const commands = @import("commands.zig");

pub const fontname = "Ubuntu-14";

pub const Arg = union {
    Int: i32,
    UInt: u32,
    float: f32,
    StringList: []const []const u8,
    String: []const u8,
};



const ActionDef = struct {
    modifier: u32,
    code: u64,
    action: fn(window: u64, arg: Arg) void,
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

pub var keys = [_]ActionDef{
    ActionDef{ .modifier = c.Mod4Mask, .code = c.XK_q, .action = commands.windowClose, .arg = undefined},
    ActionDef{ .modifier = c.Mod4Mask | c.ShiftMask, .code = c.XK_e, .action = commands.exit, .arg = undefined},

    // Window Management
    ActionDef{ .modifier = c.Mod4Mask, .code = c.XK_j, .action = commands.windowPrevious, .arg = Arg{.UInt=0}},
    ActionDef{ .modifier = c.Mod4Mask, .code = c.XK_k, .action = commands.windowNext, .arg = Arg{.UInt=0}},

    // Workspace Management
    ActionDef{ .modifier = c.Mod4Mask, .code = c.XK_1, .action = commands.workspaceShow, .arg = Arg{.UInt=0}},
    ActionDef{ .modifier = c.Mod4Mask, .code = c.XK_2, .action = commands.workspaceShow, .arg = Arg{.UInt=1}},
    ActionDef{ .modifier = c.Mod4Mask, .code = c.XK_3, .action = commands.workspaceShow, .arg = Arg{.UInt=2}},
    ActionDef{ .modifier = c.Mod4Mask, .code = c.XK_4, .action = commands.workspaceShow, .arg = Arg{.UInt=3}},
    ActionDef{ .modifier = c.Mod4Mask, .code = c.XK_5, .action = commands.workspaceShow, .arg = Arg{.UInt=4}},
    ActionDef{ .modifier = c.Mod4Mask, .code = c.XK_6, .action = commands.workspaceShow, .arg = Arg{.UInt=5}},
    ActionDef{ .modifier = c.Mod4Mask, .code = c.XK_7, .action = commands.workspaceShow, .arg = Arg{.UInt=6}},
    ActionDef{ .modifier = c.Mod4Mask, .code = c.XK_8, .action = commands.workspaceShow, .arg = Arg{.UInt=7}},

    ActionDef{ .modifier = c.Mod4Mask, .code = c.XK_Tab, .action = commands.workspaceFocusPrevious, .arg = Arg{.UInt=0}},

    // Screen selection
    // TODO: my motior order is swapped
    ActionDef{ .modifier = c.Mod4Mask, .code = c.XK_period, .action = commands.screenSelectByDelta, .arg = Arg{.Int=-1}},
    ActionDef{ .modifier = c.Mod4Mask, .code = c.XK_comma, .action = commands.screenSelectByDelta, .arg = Arg{.Int=1}},

    // Applications
    // TODO: use environment variables for term, browser, launcher
    ActionDef{ .modifier = c.Mod4Mask, .code = c.XK_p, .action = commands.run, .arg = Arg{.StringList=&[_][]const u8{"rofi", "-show", "run"}}},
    ActionDef{ .modifier = c.Mod4Mask, .code = c.XK_Return, .action = commands.run, .arg = Arg{.StringList=&[_][]const u8{"alacritty"}}},
    ActionDef{ .modifier = c.Mod4Mask, .code = c.XK_b, .action = commands.run, .arg = Arg{.StringList=&[_][]const u8{"chromium"}}},
    ActionDef{ .modifier = c.Mod4Mask, .code = c.XK_m, .action = commands.run, .arg = Arg{.StringList=&[_][]const u8{"notify-send", "-t", "200", "test message"}}},
    ActionDef{ .modifier = c.Mod4Mask, .code = c.XK_n, .action = commands.notify, .arg = Arg{.String="Test Message"}},
};

pub var buttons = [_]ActionDef{
    ActionDef{ .modifier = c.Mod1Mask, .code = c.Button1, .action = commands.windowMove, .arg = Arg{.UInt=0}},
};
