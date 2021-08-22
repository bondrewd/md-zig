const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Real = @import("config.zig").Real;
const ansi = @import("ansi-zig/src/ansi.zig");
const stopWithErrorMsg = @import("exception.zig").stopWithErrorMsg;

// Ansi format
const reset = ansi.reset;
const bold = ansi.bold_on;
const blue = ansi.fg_light_blue;
const yellow = ansi.fg_light_yellow;

pub const Input = struct {
    dt: Real,
    density: Real,
    temperature: Real,
    cell: [3]u64,
    step_save: u64,
    step_total: u64,

    const Self = @This();

    pub fn init(input_file: []const u8) !Self {
        var input: Input = undefined;

        const f = try std.fs.cwd().openFile(input_file, .{ .read = true });
        const r = f.reader();

        var buffer: [1024]u8 = undefined;
        while (try r.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
            var tokens = mem.tokenize(u8, line, " ");
            while (tokens.next()) |token| {
                if (mem.eql(u8, token, "dt")) {
                    if (tokens.next()) |dt| {
                        input.dt = fmt.parseFloat(Real, dt) catch blk: {
                            try stopWithErrorMsg("Invalid dt value!");
                            break :blk 0;
                        };
                    } else {
                        try stopWithErrorMsg("dt value is absent!");
                    }
                } else if (mem.eql(u8, token, "density")) {
                    if (tokens.next()) |density| {
                        input.density = fmt.parseFloat(Real, density) catch blk: {
                            try stopWithErrorMsg("Invalid density value!");
                            break :blk 0;
                        };
                    } else {
                        try stopWithErrorMsg("density value is absent!");
                    }
                } else if (mem.eql(u8, token, "cell")) {
                    if (tokens.next()) |cell_x| {
                        input.cell[0] = fmt.parseInt(u64, cell_x, 10) catch blk: {
                            try stopWithErrorMsg("Invalid cell X value!");
                            break :blk 0;
                        };
                    } else {
                        try stopWithErrorMsg("cell X value is absent!");
                    }
                    if (tokens.next()) |cell_y| {
                        input.cell[1] = fmt.parseInt(u64, cell_y, 10) catch blk: {
                            try stopWithErrorMsg("Invalid cell Y value!");
                            break :blk 0;
                        };
                    } else {
                        try stopWithErrorMsg("cell Y value is absent!");
                    }
                    if (tokens.next()) |cell_z| {
                        input.cell[2] = fmt.parseInt(u64, cell_z, 10) catch blk: {
                            try stopWithErrorMsg("Invalid cell Z value!");
                            break :blk 0;
                        };
                    } else {
                        try stopWithErrorMsg("cell Z value is absent!");
                    }
                } else if (mem.eql(u8, token, "temperature")) {
                    if (tokens.next()) |temperature| {
                        input.temperature = fmt.parseFloat(Real, temperature) catch blk: {
                            try stopWithErrorMsg("Invalid temperature value!");
                            break :blk 0;
                        };
                    } else {
                        try stopWithErrorMsg("temperature value is absent!");
                    }
                } else if (mem.eql(u8, token, "step_save")) {
                    if (tokens.next()) |step_save| {
                        input.step_save = fmt.parseInt(u64, step_save, 10) catch blk: {
                            try stopWithErrorMsg("Invalid step_save value!");
                            break :blk 0;
                        };
                    } else {
                        try stopWithErrorMsg("step_save value is absent!");
                    }
                } else if (mem.eql(u8, token, "step_total")) {
                    if (tokens.next()) |step_total| {
                        input.step_total = fmt.parseInt(u64, step_total, 10) catch blk: {
                            try stopWithErrorMsg("Invalid step_total value!");
                            break :blk 0;
                        };
                    } else {
                        try stopWithErrorMsg("step_total value is absent!\n");
                    }
                }
            }
        }

        return input;
    }

    pub fn displayValues(self: Self) !void {
        // Get stdout
        const stdout = std.io.getStdOut().writer();

        // Print header
        try stdout.writeAll(bold ++ yellow ++ "> INPUT:\n" ++ reset);
        try stdout.writeAll("\n");
        try stdout.print(bold ++ blue ++ "    dt:          " ++ reset ++ bold ++ "{d:<5.3}" ++ reset ++ "\n", .{self.dt});
        try stdout.print(bold ++ blue ++ "    density:     " ++ reset ++ bold ++ "{d:<5.3}" ++ reset ++ "\n", .{self.density});
        try stdout.print(bold ++ blue ++ "    temperature: " ++ reset ++ bold ++ "{d:<6.2}" ++ reset ++ "\n", .{self.temperature});
        try stdout.writeAll("\n");
        try stdout.print(bold ++ blue ++ "    cell:        " ++ reset ++ bold ++ "{d:<7} {d:<7} {d:<7}" ++ reset ++ "\n", .{ self.cell[0], self.cell[1], self.cell[2] });
        try stdout.writeAll("\n");
        try stdout.print(bold ++ blue ++ "    step_save:   " ++ reset ++ bold ++ "{d:<10}" ++ reset ++ "\n", .{self.step_save});
        try stdout.print(bold ++ blue ++ "    step_total:  " ++ reset ++ bold ++ "{d:<10}" ++ reset ++ "\n", .{self.step_total});
    }
};
