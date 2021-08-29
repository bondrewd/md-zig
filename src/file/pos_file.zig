const std = @import("std");
const Vec = @import("../vec.zig").Vec;
const Real = @import("../config.zig").Real;
const stopWithErrorMsg = @import("../exception.zig").stopWithErrorMsg;

const PosFileData = struct {
    id: std.ArrayList(u64),
    pos: std.ArrayList(Vec),
    time: Real,
};

pub const PosFile = struct {
    allocator: *std.mem.Allocator = undefined,
    writer: ?std.fs.File.Writer = undefined,
    reader: ?std.fs.File.Reader = undefined,
    file: ?std.fs.File = undefined,
    data: PosFileData = undefined,

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .data = .{
                .id = std.ArrayList(u64).init(allocator),
                .pos = std.ArrayList(Vec).init(allocator),
                .time = 0.0,
            },
        };
    }

    pub fn deinit(self: Self) void {
        if (self.file) |file| file.close();
        self.data.id.deinit();
        self.data.pos.deinit();
    }

    pub fn openFile(self: *Self, file_name: []const u8, flags: std.fs.File.OpenFlags) !void {
        var file = try std.fs.cwd().openFile(file_name, flags);
        self.file = file;
        if (flags.read) self.reader = file.reader();
        if (flags.write) self.writer = file.writer();
    }

    pub fn createFile(self: *Self, file_name: []const u8, flags: std.fs.File.CreateFlags) !void {
        var file = try std.fs.cwd().createFile(file_name, flags);
        self.file = file;
        if (flags.read) self.reader = file.reader();
        self.writer = file.writer();
    }

    pub fn load(self: *Self) !void {
        // Get file
        var f = if (self.file) |file| file else {
            try stopWithErrorMsg("Can't load pos file before open one", .{});
            unreachable;
        };

        // Get reader
        var r = if (self.reader) |reader| reader else {
            try stopWithErrorMsg("Can't load pos file without read flag on", .{});
            unreachable;
        };

        // Got the first line
        try f.seekTo(0);

        // Declare buffer
        var buf: [1024]u8 = undefined;

        // Iterate over lines
        var line_id: usize = 0;
        while (try r.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            // Update line number
            line_id += 1;

            // Skip comments
            if (std.mem.startsWith(u8, line, "#")) continue;

            // Skip empty lines
            if (std.mem.trim(u8, line, " ").len == 0) continue;

            // Parse line
            if (std.mem.startsWith(u8, line, "time")) {
                const time = std.mem.trim(u8, line[4..], " ");
                self.data.time = std.fmt.parseFloat(Real, time) catch {
                    try stopWithErrorMsg("Bad time value {s} in line {s}", .{ time, line });
                    unreachable;
                };
                continue;
            }

            var tokens = std.mem.tokenize(u8, line, " ");

            // Save index
            try self.data.id.append(if (tokens.next()) |token| std.fmt.parseInt(u64, token, 10) catch {
                try stopWithErrorMsg("Bad index value {s} in line {s}", .{ token, line });
                unreachable;
            } else {
                try stopWithErrorMsg("Missing index value at line #{d} -> {s}", .{ line_id, line });
                unreachable;
            });

            // Save positions
            try self.data.pos.append(Vec{
                .x = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                    try stopWithErrorMsg("Bad x position value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    try stopWithErrorMsg("Missing x position value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                },
                .y = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                    try stopWithErrorMsg("Bad x position value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    try stopWithErrorMsg("Missing x position value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                },
                .z = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                    try stopWithErrorMsg("Bad x position value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    try stopWithErrorMsg("Missing x position value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                },
            });
        }
    }
};
