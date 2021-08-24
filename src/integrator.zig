const std = @import("std");
const vec = @import("vec.zig");
const System = @import("system.zig").System;
const stopWithErrorMsg = @import("exception.zig").stopWithErrorMsg;

pub fn leapFrog(system: *System) void {
    // Time step
    const dt = system.time_step;

    // First part
    for (system.atoms) |*atom| {
        // v(t + dt/2) = v(t) + f(t) * dt/2m
        atom.v = vec.add(atom.v, vec.scale(atom.f, 0.5 * dt / atom.m));
        // x(t + dt) = x(t) + v(t + dt/2) * dt
        atom.r = vec.add(atom.r, vec.scale(atom.v, dt));
    }

    // Update forces
    // f(t + dt) = -dU(t + dt)/dt
    system.updateForces();

    // Second part
    for (system.atoms) |*atom| {
        // v(t + dt) = v(t + dt/2) + f(t + dt) * dt/2m
        atom.v = vec.add(atom.v, vec.scale(atom.f, 0.5 * dt / atom.m));
    }
}

pub fn integratorFromString(integrator_str: []const u8) !fn (*System) void {
    const integrator = std.mem.trim(u8, integrator_str, " ");
    if (std.mem.eql(u8, "LEAP", integrator)) {
        return leapFrog;
    } else {
        try stopWithErrorMsg("Unknown integrator -> {s}", .{integrator});
        unreachable;
    }
}
