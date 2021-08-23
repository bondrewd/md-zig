const std = @import("std");
const vec = @import("vec.zig");
const Vec = @import("vec.zig").Vec;
const Atom = @import("atom.zig").Atom;
const Real = @import("config.zig").Real;
const integratorFromString = @import("integrator.zig").integratorFromString;

pub const System = struct {
    allocator: *std.mem.Allocator = undefined,
    integrator: fn (*Self) void = undefined,
    time_step: Real = undefined,
    random: Random = undefined,
    region: Vec = Vec{},
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

    const Random = struct {
        seed: u64,
        rng: std.rand.DefaultPrng,
    };

    const Self = @This();

    pub const SystemConfiguration = struct {
        allocator: *std.mem.Allocator,
        integrator: []const u8,
        time_step: Real,
        rng_seed: u64,
    };

    pub fn init(config: SystemConfiguration) !Self {
        var system = System{};

        // Set allocator
        system.allocator = config.allocator;

        // Set integrator
        system.integrator = try integratorFromString(config.integrator);

        // Set time step
        system.time_step = config.time_step;

        // Set rng
        const rng_seed = if (config.rng_seed > 0) config.rng_seed else blk: {
            var seed: u64 = undefined;
            try std.os.getrandom(std.mem.asBytes(&seed));
            break :blk seed;
        };
        system.random = Random{
            .seed = rng_seed,
            .rng = std.rand.DefaultPrng.init(rng_seed),
        };

        return system;
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.atoms);
    }

    pub fn initVelocities(self: *Self, temperature: Real) !void {
        // Get rng
        const rand = &self.random.rng.random;

        // Initialize local variables
        var v_sum = Vec{};
        const n_atoms = @intToFloat(Real, self.atoms.len);
        const vel = std.math.sqrt(3.0 * (1.0 - 1.0 / n_atoms) * temperature);

        // Initialize with random velocities
        for (self.atoms) |*atom| {
            // Create a random unit vector
            var v_random = Vec{
                .x = rand.float(Real),
                .y = rand.float(Real),
                .z = rand.float(Real),
            };
            v_random = vec.normalize(v_random);

            // Assign random velocity
            atom.v = vec.scale(v_random, vel);
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
