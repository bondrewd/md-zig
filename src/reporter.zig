const Real = @import("config.zig").Real;
const System = @import("system.zig").System;

pub const Reporter = struct {
    system: *System,

    const Self = @This();

    pub fn init(s: *System) Self {
        return Reporter{ .system = s };
    }

    pub fn writeHeader(_: Self, writer: anytype) !void {
        try writer.print("#{s:>12} {s:>12} {s:>12} {s:>12} {s:>12} {s:>12}\n", .{
            "step",
            "time",
            "temperature",
            "kinetic",
            "potential",
            "total",
        });
    }

    pub fn report(self: Self, writer: anytype, step: u64) !void {
        try writer.print(" {d:>12} {d:>12.3} {e:>12.5} {e:>12.5} {e:>12.5} {e:>12.5}\n", .{
            step,
            @intToFloat(Real, step) * self.system.dt,
            self.system.temperature,
            self.system.energy.kinetic,
            self.system.energy.potential,
            self.system.energy.total,
        });
    }
};
