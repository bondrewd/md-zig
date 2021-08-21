const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Real = @import("config.zig").Real;
const stopWithErrorMsg = @import("exception.zig").stopWithErrorMsg;

pub const Input = struct {
    dt: Real,
    density: Real,
    cell: [3]Real,
    temperature: Real,
    step_avg: u64,
    step_eq: u64,
    step_total: u64,

    const Self = @This();

    pub fn init(input_file: []const u8) !Self {
        var input: Input = undefined;

        const f = try std.fs.cwd().openFile(input_file, .{ .read = true });
        const r = f.reader();

        var buffer: [1024]u8 = undefined;
        while (try r.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
            var tokens = mem.tokenize(line, " ");
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
                        input.cell[0] = fmt.parseFloat(Real, cell_x) catch blk: {
                            try stopWithErrorMsg("Invalid cell X value!");
                            break :blk 0;
                        };
                    } else {
                        try stopWithErrorMsg("cell X value is absent!");
                    }
                    if (tokens.next()) |cell_y| {
                        input.cell[1] = fmt.parseFloat(Real, cell_y) catch blk: {
                            try stopWithErrorMsg("Invalid cell Y value!");
                            break :blk 0;
                        };
                    } else {
                        try stopWithErrorMsg("cell Y value is absent!");
                    }
                    if (tokens.next()) |cell_z| {
                        input.cell[2] = fmt.parseFloat(Real, cell_z) catch blk: {
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
                } else if (mem.eql(u8, token, "step_avg")) {
                    if (tokens.next()) |step_avg| {
                        input.step_avg = fmt.parseInt(u64, step_avg, 10) catch blk: {
                            try stopWithErrorMsg("Invalid step_avg value!");
                            break :blk 0;
                        };
                    } else {
                        try stopWithErrorMsg("step_avg value is absent!");
                    }
                } else if (mem.eql(u8, token, "step_eq")) {
                    if (tokens.next()) |step_eq| {
                        input.step_eq = fmt.parseInt(u64, step_eq, 10) catch blk: {
                            try stopWithErrorMsg("Invalid step_eq value!");
                            break :blk 0;
                        };
                    } else {
                        try stopWithErrorMsg("step_eq value is absent!");
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
};
