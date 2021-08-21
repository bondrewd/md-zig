const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Real = @import("config.zig").Real;

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
                        input.dt = try fmt.parseFloat(Real, dt);
                    } else {
                        std.debug.print("Error, no dt value!\n", .{});
                    }
                } else if (mem.eql(u8, token, "density")) {
                    if (tokens.next()) |density| {
                        input.density = try fmt.parseFloat(Real, density);
                    } else {
                        std.debug.print("Error, no density value!\n", .{});
                    }
                } else if (mem.eql(u8, token, "cell")) {
                    if (tokens.next()) |cell_x| {
                        input.cell[0] = try fmt.parseFloat(Real, cell_x);
                    } else {
                        std.debug.print("Error, no cell X value!\n", .{});
                    }
                    if (tokens.next()) |cell_y| {
                        input.cell[1] = try fmt.parseFloat(Real, cell_y);
                    } else {
                        std.debug.print("Error, no cell Y value!\n", .{});
                    }
                    if (tokens.next()) |cell_z| {
                        input.cell[2] = try fmt.parseFloat(Real, cell_z);
                    } else {
                        std.debug.print("Error, no cell Z value!\n", .{});
                    }
                } else if (mem.eql(u8, token, "temperature")) {
                    if (tokens.next()) |temperature| {
                        input.temperature = try fmt.parseFloat(Real, temperature);
                    } else {
                        std.debug.print("Error, no temperature value!\n", .{});
                    }
                } else if (mem.eql(u8, token, "step_avg")) {
                    if (tokens.next()) |step_avg| {
                        input.step_avg = try fmt.parseInt(u64, step_avg, 10);
                    } else {
                        std.debug.print("Error, no step_avg value!\n", .{});
                    }
                } else if (mem.eql(u8, token, "step_eq")) {
                    if (tokens.next()) |step_eq| {
                        input.step_eq = try fmt.parseInt(u64, step_eq, 10);
                    } else {
                        std.debug.print("Error, no step_eq value!\n", .{});
                    }
                } else if (mem.eql(u8, token, "step_total")) {
                    if (tokens.next()) |step_total| {
                        input.step_total = try fmt.parseInt(u64, step_total, 10);
                    } else {
                        std.debug.print("Error, no step_total value!\n", .{});
                    }
                }
            }
        }

        return input;
    }
};
