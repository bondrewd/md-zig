const std = @import("std");

const red = @import("config.zig").red;
const bold = @import("config.zig").bold;
const reset = @import("config.zig").reset;

pub fn stopWithErrorMsg(comptime error_msg: []const u8, args: anytype) void {
    // Get stdout
    const stdout = std.io.getStdOut().writer();

    // Print message
    stdout.writeAll(bold ++ red ++ "Error: " ++ reset) catch unreachable;
    stdout.print(error_msg, args) catch unreachable;
    stdout.writeAll("\n") catch unreachable;

    std.os.exit(0);
}
