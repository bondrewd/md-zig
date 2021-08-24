const std = @import("std");
const Vec = @import("../vec.zig").Vec;
const Real = @import("../config.zig").Real;
const stopWithErrorMsg = @import("../exception.zig").stopWithErrorMsg;

pub const PosFileParserConfiguration = struct {
    line_buffer_size: usize = 1024,
    comment_character: []const u8 = "#",
};

pub fn PosFile(comptime config: PosFileParserConfiguration) type {
    return struct {
        allocator: *std.mem.Allocator,
        len: usize = undefined,
        pos: []Vec = undefined,
        id: []u64 = undefined,

        const Self = @This();

        pub fn initFile(allocator: *std.mem.Allocator, file: std.fs.File) !Self {
            // Allocate array for positions and indexes
            var pos = std.ArrayList(Vec).init(allocator);
            defer pos.deinit();
            var id = std.ArrayList(u64).init(allocator);
            defer id.deinit();

            // Got the first line
            try file.seekTo(0);

            // Get reader
            var r = file.reader();

            // Declare buffer
            var buf: [config.line_buffer_size]u8 = undefined;

            // Iterate over lines
            var line_id: usize = 0;
            while (try r.readUntilDelimiterOrEof(&buf, '\n')) |line| {
                // Update line number
                line_id += 1;

                // Skip comments
                if (std.mem.startsWith(u8, line, config.comment_character)) continue;

                // Skip empty lines
                if (std.mem.trim(u8, line, " ").len == 0) continue;

                // Parse line
                var tokens = std.mem.tokenize(u8, line, " ");
                try id.append(if (tokens.next()) |token| std.fmt.parseInt(u64, token, 10) catch {
                    try stopWithErrorMsg("Bad index value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    try stopWithErrorMsg("Missing index value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                });

                try pos.append(Vec{
                    .x = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                        try stopWithErrorMsg("Bad x position value {s} in line {s}", .{ token, line });
                        unreachable;
                    } else {
                        try stopWithErrorMsg("Missing x position value at line #{d} -> {s}", .{ line_id, line });
                        unreachable;
                    },
                    .y = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                        try stopWithErrorMsg("Bad y position value {s} in line {s}", .{ token, line });
                        unreachable;
                    } else {
                        try stopWithErrorMsg("Missing y position value at line #{d} -> {s}", .{ line_id, line });
                        unreachable;
                    },
                    .z = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                        try stopWithErrorMsg("Bad z position value {s} in line {s}", .{ token, line });
                        unreachable;
                    } else {
                        try stopWithErrorMsg("Missing z position value at line #{d} -> {s}", .{ line_id, line });
                        unreachable;
                    },
                });
            }

            return Self{
                .allocator = allocator,
                .len = pos.items.len,
                .pos = pos.toOwnedSlice(),
                .id = id.toOwnedSlice(),
            };
        }

        pub fn init(allocator: *std.mem.Allocator, file_name: []const u8) !Self {
            // Open pos file
            var f = try std.fs.cwd().openFile(file_name, .{ .read = true });

            // Parse file
            return try initFile(allocator, f);
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.pos);
            self.allocator.free(self.id);
        }
    };
}
