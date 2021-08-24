const std = @import("std");

const red = @import("config.zig").red;
const bold = @import("config.zig").bold;
const reset = @import("config.zig").reset;

pub fn stopWithErrorMsg(comptime error_msg: []const u8, args: anytype) !void {
    // Get stdout
    const stdout = std.io.getStdOut().writer();

    // Print message
    try stdout.writeAll(bold ++ red ++ "Error: " ++ reset);
    try stdout.print(error_msg, args);
    try stdout.writeAll("\n");

    std.os.exit(0);
}
