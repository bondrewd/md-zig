const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Real = @import("config.zig").Real;
const stopWithErrorMsg = @import("exception.zig").stopWithErrorMsg;

const bold = @import("config.zig").bold;
const blue = @import("config.zig").blue;
const reset = @import("config.zig").reset;
const yellow = @import("config.zig").yellow;

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

        var flags = [_]bool{false} ** 6;

        const f = try std.fs.cwd().openFile(input_file, .{ .read = true });
        const r = f.reader();

        var buffer: [1024]u8 = undefined;
        while (try r.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
            var tokens = mem.tokenize(u8, line, " ");
            while (tokens.next()) |token| {
                if (mem.eql(u8, token, "dt")) {
                    flags[0] = true;
                    if (tokens.next()) |dt| {
                        input.dt = fmt.parseFloat(Real, dt) catch blk: {
                            try stopWithErrorMsg("Invalid dt value!");
                            break :blk 0;
                        };
                    } else {
                        try stopWithErrorMsg("dt value is absent!");
                    }
                } else if (mem.eql(u8, token, "density")) {
                    flags[1] = true;
                    if (tokens.next()) |density| {
                        input.density = fmt.parseFloat(Real, density) catch blk: {
                            try stopWithErrorMsg("Invalid density value!");
                            break :blk 0;
                        };
                    } else {
                        try stopWithErrorMsg("density value is absent!");
                    }
                } else if (mem.eql(u8, token, "cell")) {
                    flags[2] = true;
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
                    flags[3] = true;
                    if (tokens.next()) |temperature| {
                        input.temperature = fmt.parseFloat(Real, temperature) catch blk: {
                            try stopWithErrorMsg("Invalid temperature value!");
                            break :blk 0;
                        };
                    } else {
                        try stopWithErrorMsg("temperature value is absent!");
                    }
                } else if (mem.eql(u8, token, "step_save")) {
                    flags[4] = true;
                    if (tokens.next()) |step_save| {
                        input.step_save = fmt.parseInt(u64, step_save, 10) catch blk: {
                            try stopWithErrorMsg("Invalid step_save value!");
                            break :blk 0;
                        };
                    } else {
                        try stopWithErrorMsg("step_save value is absent!");
                    }
                } else if (mem.eql(u8, token, "step_total")) {
                    flags[5] = true;
                    if (tokens.next()) |step_total| {
                        input.step_total = fmt.parseInt(u64, step_total, 10) catch blk: {
                            try stopWithErrorMsg("Invalid step_total value!");
                            break :blk 0;
                        };
                    } else {
                        try stopWithErrorMsg("step_total value is absent!");
                    }
                }
            }
        }

        for (flags) |flag, i| {
            if (!flag and i == 0) try stopWithErrorMsg("missing dt in input file!");
            if (!flag and i == 1) try stopWithErrorMsg("missing density in input file!");
            if (!flag and i == 2) try stopWithErrorMsg("missing temperature in input file!");
            if (!flag and i == 3) try stopWithErrorMsg("missing cell in input file!");
            if (!flag and i == 4) try stopWithErrorMsg("missing step_save in input file!");
            if (!flag and i == 5) try stopWithErrorMsg("missing step_total in input file!");
        }

        return input;
    }

    pub fn displayValues(self: Self) !void {
        // Get stdout
        const stdout = std.io.getStdOut().writer();

        // Print header
        try stdout.writeAll(bold ++ yellow ++ "> INPUT:\n" ++ reset);
        try stdout.print(bold ++ blue ++ "    dt:           " ++ reset ++ "{d:<5.3}\n", .{self.dt});
        try stdout.print(bold ++ blue ++ "    density:      " ++ reset ++ "{d:<5.3}\n", .{self.density});
        try stdout.print(bold ++ blue ++ "    temperature:  " ++ reset ++ "{d:<6.2}\n", .{self.temperature});
        try stdout.print(bold ++ blue ++ "    cell:         " ++ reset ++ "{d:<7} {d:<7} {d:<7}\n", .{ self.cell[0], self.cell[1], self.cell[2] });
        try stdout.print(bold ++ blue ++ "    step_save:    " ++ reset ++ "{d:<10}\n", .{self.step_save});
        try stdout.print(bold ++ blue ++ "    step_total:   " ++ reset ++ "{d:<10}\n", .{self.step_total});
    }
};
