const std = @import("std");

const math = @import("../math.zig");
const V3 = math.V3;
const M3x3 = math.M3x3;

const Real = @import("../config.zig").Real;
const System = @import("../system.zig").System;
const stopWithErrorMsg = @import("../exception.zig").stopWithErrorMsg;

const VelFileData = struct {
    id: std.ArrayList(u64),
    vel: std.ArrayList(V3),
    time: Real,
};

pub const VelFile = struct {
    allocator: *std.mem.Allocator = undefined,
    writer: ?std.fs.File.Writer = undefined,
    reader: ?std.fs.File.Reader = undefined,
    file: ?std.fs.File = undefined,
    data: VelFileData = undefined,

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .data = .{
                .id = std.ArrayList(u64).init(allocator),
                .vel = std.ArrayList(V3).init(allocator),
                .time = 0.0,
            },
        };
    }

    pub fn deinit(self: Self) void {
        if (self.file) |file| file.close();
        self.data.id.deinit();
        self.data.vel.deinit();
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
            try stopWithErrorMsg("Can't load vel file before open one", .{});
            unreachable;
        };

        // Get reader
        var r = if (self.reader) |reader| reader else {
            try stopWithErrorMsg("Can't load vel file without read flag on", .{});
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
            const index = if (tokens.next()) |token| std.fmt.parseInt(u64, token, 10) catch {
                try stopWithErrorMsg("Bad index value {s} in line {s}", .{ token, line });
                unreachable;
            } else {
                try stopWithErrorMsg("Missing index value at line #{d} -> {s}", .{ line_id, line });
                unreachable;
            };

            try self.data.id.append(index);

            // Save velocities
            const vx = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                try stopWithErrorMsg("Bad x velocity value {s} in line {s}", .{ token, line });
                unreachable;
            } else {
                try stopWithErrorMsg("Missing x velocity value at line #{d} -> {s}", .{ line_id, line });
                unreachable;
            };
            const vy = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                try stopWithErrorMsg("Bad x velocity value {s} in line {s}", .{ token, line });
                unreachable;
            } else {
                try stopWithErrorMsg("Missing x velocity value at line #{d} -> {s}", .{ line_id, line });
                unreachable;
            };
            const vz = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                try stopWithErrorMsg("Bad x velocity value {s} in line {s}", .{ token, line });
                unreachable;
            } else {
                try stopWithErrorMsg("Missing x velocity value at line #{d} -> {s}", .{ line_id, line });
                unreachable;
            };

            try self.data.vel.append(V3.fromArray(.{ vx, vy, vz }));
        }
    }

    pub fn printDataFromSystem(self: Self, system: *System) !void {
        // Get writer
        var w = if (self.writer) |w| w else {
            try stopWithErrorMsg("Can't print vel file before open or create one", .{});
            unreachable;
        };

        // Write number of entries
        const time = @intToFloat(Real, system.current_step) * system.integrator.dt;
        try w.print("time {d:>8.3}\n", .{time});

        // Print header
        try w.print("#{s:>11}  {s:>12}  {s:>12}  {s:>12}\n", .{
            "id",
            "vx",
            "vy",
            "vz",
        });
        try w.print("#{s:>11}  {s:>12}  {s:>12}  {s:>12}\n", .{
            " ",
            "nm/ps",
            "nm/ps",
            "nm/ps",
        });

        // Write velocities
        for (system.v) |v, i| {
            try w.print("{d:>12}  {e:>12.5}  {e:>12.5}  {e:>12.5}\n", .{
                system.id[i],
                v.items[0],
                v.items[1],
                v.items[2],
            });
        }
        // Write new line
        try w.writeAll("\n");
    }
};
