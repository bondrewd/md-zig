const std = @import("std");
const Real = @import("../config.zig").Real;
const System = @import("../system.zig").System;
const Input = @import("../input.zig").MdInputFileParserResult;

pub const TsFile = struct {
    writer: std.fs.File.Writer = undefined,
    file: std.fs.File = undefined,

    const Self = @This();

    pub fn init(input: Input) !Self {
        // Declare reporter
        var ts_file = Self{};

        // Set file
        const file_name = std.mem.trim(u8, input.out_ts_name, " ");
        var file = try std.fs.cwd().createFile(file_name, .{});
        ts_file.file = file;

        // Set writer
        ts_file.writer = file.writer();

        // Print header
        try ts_file.printHeader();

        return ts_file;
    }

    pub fn deinit(self: *Self) void {
        self.file.close();
    }

    pub fn printHeader(self: Self) !void {
        try self.writer.print("#{s:>12} {s:>12} {s:>12} {s:>12} {s:>12} {s:>12}\n", .{
            "step",
            "time",
            "temperature",
            "kinetic",
            "potential",
            "total",
        });
    }

    pub fn printDataLine(self: Self, system: *System) !void {
        try self.writer.print(" {d:>12} {d:>12.3} {e:>12.5} {e:>12.5} {e:>12.5} {e:>12.5}\n", .{
            system.current_step,
            @intToFloat(Real, system.current_step) * system.integrator.dt,
            system.temperature,
            system.energy.kinetic,
            system.energy.potential,
            system.energy.kinetic + system.energy.potential,
        });
    }
};
