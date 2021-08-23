const std = @import("std");
const vec = @import("vec.zig");
const Atom = @import("atom.zig").Atom;
const Real = @import("config.zig").Real;
const integratorFromString = @import("integrator.zig").integratorFromString;

pub const System = struct {
    allocator: *std.mem.Allocator = undefined,
    integrator: fn (*Self) void = undefined,
    time_step: Real = undefined,
    region: vec.Vec = vec.Vec{},
    atoms: []Atom = undefined,
    properties: SystemProperties = SystemProperties{},

    const Energy = struct {
        kinetic: Real = 0,
        potential: Real = 0,
        total: Real = 0,
    };

    const SystemProperties = struct {
        energy: Energy = Energy{},
        temperature: Real = 0,
    };

    const Self = @This();

    pub const SystemConfiguration = struct {
        allocator: *std.mem.Allocator,
        integrator: []const u8,
        time_step: Real,
    };

    pub fn init(config: SystemConfiguration) !Self {
        var system = System{};

        // Set allocator
        system.allocator = config.allocator;

        // Set integrator
        system.integrator = try integratorFromString(config.integrator);

        // Set time step
        system.time_step = config.time_step;

        return system;
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.atoms);
    }

    pub fn initVelocities(self: *Self, temperature: Real) !void {
        // Initialize random number generator
        var prng = std.rand.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            try std.os.getrandom(std.mem.asBytes(&seed));
            break :blk seed;
        });
        const rand = &prng.random;

        // Initialize local variables
        var v_sum = vec.Vec{};
        const n_atoms = @intToFloat(Real, self.atoms.len);
        const velocity = std.math.sqrt(3.0 * (1.0 - 1.0 / n_atoms) * temperature);

        // Initialize with random velocities
        for (self.atoms) |*atom| {
            // Create a random unit vector
            var v_random = vec.Vec{ .x = rand.float(Real), .y = rand.float(Real), .z = rand.float(Real) };
            v_random = vec.normalize(v_random);

            // Assign random velocity
            atom.v = vec.scale(v_random, velocity);
            v_sum = vec.add(v_sum, atom.v);
        }

        // Calculate system velocity
        const v_avg = vec.scale(v_sum, 1.0 / n_atoms);

        // Remove system velocity
        for (self.atoms) |*atom| {
            atom.v = vec.sub(atom.v, v_avg);
        }
    }

    pub fn updateForces(_: Self) void {}

    pub fn updateKineticEnergy(self: *Self) void {
        var kinetic: Real = 0.0;
        for (self.atoms) |atom| {
            kinetic += vec.dot(atom.v, atom.v);
        }

        self.properties.energy.kinetic = 0.5 * kinetic;
    }

    pub fn updateEnergy(self: *Self) void {
        self.updateKineticEnergy();
        self.properties.energy.total = self.properties.energy.kinetic + self.properties.energy.potential;
    }
};
