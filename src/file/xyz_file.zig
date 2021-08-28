const std = @import("std");
const Real = @import("../config.zig").Real;
const System = @import("../system.zig").System;
const Input = @import("../input.zig").MdInputFileParserResult;

pub const XyzFile = struct {
    writer: std.fs.File.Writer = undefined,
    file: std.fs.File = undefined,

    const Self = @This();

    pub fn init(input: Input) !Self {
        // Declare reporter
        var xyz_file = Self{};

        // Set file
        const file_name = std.mem.trim(u8, input.out_xyz_name, " ");
        var file = try std.fs.cwd().createFile(file_name, .{});
        xyz_file.file = file;

        // Set writer
        xyz_file.writer = file.writer();

        return xyz_file;
    }

    pub fn deinit(self: *Self) void {
        self.file.close();
    }

    pub fn printDataFrame(self: Self, system: *System) !void {
        try self.writer.print("{d}\n", .{system.r.len});
        try self.writer.print("\n", .{});
        for (system.r) |r| {
            try self.writer.print("H  {d:>8.3}  {d:>8.3}  {d:>8.3}\n", .{
                r.x,
                r.y,
                r.z,
            });
        }
    }
};
