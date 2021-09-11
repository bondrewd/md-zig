const std = @import("std");
const V3 = @import("math.zig").V3;
const Real = @import("config.zig").Real;
const System = @import("system.zig").System;
const Input = @import("input.zig").MdInputFileParserResult;
const stopWithErrorMsg = @import("exception.zig").stopWithErrorMsg;

pub const Integrator = struct {
    dt: Real = undefined,
    evolveSystem: fn (*System) void = undefined,

    const Self = @This();

    pub fn init(input: Input) Self {
        // Declare integrator
        var integrator = Integrator{};

        // Set time step
        integrator.dt = input.time_step;

        // Get integrator name
        const name = std.mem.trim(u8, input.integrator, " ");

        // Parse integrator name
        if (std.mem.eql(u8, "LEAP", name)) {
            integrator.evolveSystem = leapFrog;
        } else {
            stopWithErrorMsg("Unknown integrator -> {s}", .{name});
            unreachable;
        }

        return integrator;
    }
};

pub fn leapFrog(system: *System) void {
    // Time step
    const dt = system.integrator.dt;

    // First part
    var i: usize = 0;
    while (i < system.r.len) : (i += 1) {
        // v(t + dt/2) = v(t) + f(t) * dt/2m
        system.v[i] = V3.addVV(system.v[i], V3.mulVS(system.f[i], 0.5 * dt / system.m[i]));
        // x(t + dt) = x(t) + v(t + dt/2) * dt
        system.r[i] = V3.addVV(system.r[i], V3.mulVS(system.v[i], dt));
    }

    // Update forces
    // f(t + dt) = -dU(t + dt)/dt
    system.calculateForceInteractions();

    // Second part
    i = 0;
    while (i < system.r.len) : (i += 1) {
        // v(t + dt) = v(t + dt/2) + f(t + dt) * dt/2m
        system.v[i] = V3.addVV(system.v[i], V3.mulVS(system.f[i], 0.5 * dt / system.m[i]));
    }
}
