const std = @import("std");
const vec = @import("vec.zig");
const Vec = @import("vec.zig").Vec;
const kb = @import("constant.zig").kb;
const Real = @import("config.zig").Real;
const PosFile = @import("file.zig").PosFile;
const MolFile = @import("file.zig").MolFile;
const ForceField = @import("ff.zig").ForceField;
const Integrator = @import("integrator.zig").Integrator;
const Input = @import("input.zig").MdInputFileParserResult;

const lennardJonesForceInteraction = @import("interaction.zig").lennardJonesForceInteraction;
const lennardJonesEnergyInteraction = @import("interaction.zig").lennardJonesEnergyInteraction;

//const integratorFromString = @import("integrator.zig").integratorFromString;

pub const System = struct {
    allocator: *std.mem.Allocator = undefined,
    rng: std.rand.DefaultPrng = undefined,
    id: []u64 = undefined,
    r: []Vec = undefined,
    v: []Vec = undefined,
    f: []Vec = undefined,
    m: []Real = undefined,
    q: []Real = undefined,
    ff: ForceField = undefined,
    temperature: Real = undefined,
    integrator: Integrator = undefined,
    energy: struct { kinetic: Real, potential: Real } = undefined,

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator, input: Input) !Self {
        // Declare system
        var system = System{};

        // Set allocator
        system.allocator = allocator;

        // Parse pos file
        var pos_file_name = std.mem.trim(u8, input.pos_file, " ");
        var pos_file = try PosFile.init(allocator, pos_file_name);
        defer pos_file.deinit();

        // Initialize ids and positions
        system.id = pos_file.id.toOwnedSlice();
        system.r = pos_file.pos.toOwnedSlice();

        // Allocate velocity, force, mass, and charge
        system.v = try allocator.alloc(Vec, system.r.len);
        system.f = try allocator.alloc(Vec, system.r.len);
        system.m = try allocator.alloc(Real, system.r.len);
        system.q = try allocator.alloc(Real, system.r.len);

        // Parse mol file
        var mol_file_name = std.mem.trim(u8, input.mol_file, " ");
        var mol_file = try MolFile.init(allocator, mol_file_name);
        defer mol_file.deinit();

        // Initialize mass and charge
        system.m = mol_file.mass.toOwnedSlice();
        system.q = mol_file.charge.toOwnedSlice();

        // Initialize force field
        var force_interactions = std.ArrayList(fn (*Self) void).init(allocator);
        defer force_interactions.deinit();
        var energy_interactions = std.ArrayList(fn (*Self) void).init(allocator);
        defer energy_interactions.deinit();

        if (mol_file.lennard_jones_parameters.items.len > 0) {
            system.ff.lennard_jones_parameters = mol_file.lennard_jones_parameters.toOwnedSlice();
            try force_interactions.append(lennardJonesForceInteraction);
            try energy_interactions.append(lennardJonesEnergyInteraction);
        }

        system.ff.force_interactions = force_interactions.toOwnedSlice();
        system.ff.energy_interactions = energy_interactions.toOwnedSlice();

        // Set rng
        var seed = if (input.rng_seed > 0) input.rng_seed else blk: {
            var s: u64 = undefined;
            try std.os.getrandom(std.mem.asBytes(&s));
            break :blk s;
        };
        system.rng = std.rand.DefaultPrng.init(seed);

        // Initialize velocities
        system.initVelocities(input.temperature);

        // Initialize forces
        system.calculateForceInteractions();

        // Initialize energies
        system.calculateEnergyInteractions();
        system.calculateKineticEnergy();

        // Initialize integrator
        system.integrator = try Integrator.init(input);

        // Initialize reporter

        return system;
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.id);
        self.allocator.free(self.r);
        self.allocator.free(self.v);
        self.allocator.free(self.f);
        self.allocator.free(self.m);
        self.allocator.free(self.q);
        self.allocator.free(self.ff.force_interactions);
        self.allocator.free(self.ff.energy_interactions);
    }

    pub fn initVelocities(self: *Self, temperature: Real) void {
        // Get rng
        const rng = &self.rng.random;

        // Initialize with random velocities
        var i: usize = 0;
        while (i < self.v.len) : (i += 1) {

            // Sigma
            const s = std.math.sqrt(kb * temperature / self.m[i]);

            // Alpha
            const a = Vec{
                .x = std.math.sqrt(-2.0 * std.math.ln(rng.float(Real))),
                .y = std.math.sqrt(-2.0 * std.math.ln(rng.float(Real))),
                .z = std.math.sqrt(-2.0 * std.math.ln(rng.float(Real))),
            };

            // Beta
            const b = Vec{
                .x = @cos(2.0 * std.math.pi * rng.float(Real)),
                .y = @cos(2.0 * std.math.pi * rng.float(Real)),
                .z = @cos(2.0 * std.math.pi * rng.float(Real)),
            };

            // Assign random velocity
            self.v[i] = vec.scale(vec.mul(a, b), s);
        }
    }

    pub fn calculateForceInteractions(self: *Self) void {
        for (self.ff.force_interactions) |f| f(self);
    }

    pub fn calculateEnergyInteractions(self: *Self) void {
        self.energy.potential = 0;
        for (self.ff.energy_interactions) |f| f(self);
    }

    pub fn calculateKineticEnergy(self: *Self) void {
        var energy: Real = 0.0;

        var i: usize = 0;
        while (i < self.v.len) : (i += 1) {
            energy += self.m[i] * vec.dot(self.v[i], self.v[i]);
        }

        self.energy.kinetic = 0.5 * energy;
    }

    pub fn calculateTemperature(self: *Self) void {
        self.calculateKineticEnergy();
        self.temperature = 2.0 * self.energy.kinetic / (3.0 * self.r.len * kb);
    }

    pub fn step(self: *Self) !void {
        self.integrator.evolveSystem(self);
    }
};
