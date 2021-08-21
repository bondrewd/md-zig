const std = @import("std");
const ansi = @import("ansi-zig/src/ansi.zig");

// Ansi format
const reset = ansi.reset;
const bold = ansi.bold_on;
const red = ansi.fg_light_red;

pub fn stopWithErrorMsg(error_msg: []const u8) !void {
    // Get stdout
    const stdout = std.io.getStdOut().writer();

    // Print message
    try stdout.print(bold ++ red ++ "Error: " ++ reset ++ "{s}\n", .{error_msg});

    std.os.exit(0);
}
