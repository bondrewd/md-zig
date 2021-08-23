const vec = @import("vec.zig");
const System = @import("system.zig").System;

pub const IntegratorType = enum {
    LeapFrog,
};

pub fn Integrator(integrator: IntegratorType) type {
    return struct {
        system: *System,

        const Self = @This();

        pub fn init(system: *System) Self {
            return Self{ .system = system };
        }

        pub fn stepLeapFrog(self: Self) void {
            // First part
            for (self.system.atoms.items) |*atom| {
                // v(t + dt/2) = v(t) + f(t) * dt/2m
                atom.v = vec.add(atom.v, vec.scale(atom.f, 0.5 * self.system.dt / atom.m));
                // x(t + dt) = x(t) + v(t + dt/2) * dt
                atom.r = vec.add(atom.r, vec.scale(atom.v, self.system.dt));
            }

            // Update forces
            // f(t + dt) = -dU(t + dt)/dt
            self.system.calculateForces();

            // Second part
            for (self.system.atoms.items) |*atom| {
                // v(t + dt) = v(t + dt/2) + f(t + dt) * dt/2m
                atom.v = vec.add(atom.v, vec.scale(atom.f, 0.5 * self.system.dt / atom.m));
            }
        }

        pub fn step(self: Self) void {
            switch (integrator) {
                .LeapFrog => self.stepLeapFrog(),
            }
        }
    };
}
