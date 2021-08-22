const std = @import("std");

const red = @import("config.zig").red;
const bold = @import("config.zig").bold;
const reset = @import("config.zig").reset;

pub fn stopWithErrorMsg(error_msg: []const u8) !void {
    // Get stdout
    const stdout = std.io.getStdOut().writer();

    // Print message
    try stdout.print(bold ++ red ++ "Error: " ++ reset ++ "{s}\n", .{error_msg});

    std.os.exit(0);
}
