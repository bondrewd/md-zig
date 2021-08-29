const std = @import("std");
const vec = @import("vec.zig");
const Vec = @import("vec.zig").Vec;
const kb = @import("constant.zig").kb;
const Real = @import("config.zig").Real;
const TsFile = @import("file.zig").TsFile;
const XyzFile = @import("file.zig").XyzFile;
const PosFile = @import("file.zig").PosFile;
const MolFile = @import("file.zig").MolFile;
const ForceField = @import("ff.zig").ForceField;
const Integrator = @import("integrator.zig").Integrator;
const Input = @import("input.zig").MdInputFileParserResult;
const NeighborList = @import("neighbor_list.zig").NeighborList;

const lennardJonesForceInteraction = @import("interaction.zig").lennardJonesForceInteraction;
const lennardJonesEnergyInteraction = @import("interaction.zig").lennardJonesEnergyInteraction;

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
    current_step: u64 = undefined,
    region: Vec = undefined,
    use_pbc: bool = undefined,
    neighbor_list: NeighborList = undefined,
    neighbor_list_update_step: u64 = undefined,

    ts_file: TsFile = undefined,
    ts_file_out: u64 = undefined,
    xyz_file: XyzFile = undefined,
    xyz_file_out: u64 = undefined,

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator, input: Input) !Self {
        // Declare system
        var system = System{};

        // Set allocator
        system.allocator = allocator;

        // Set current step
        system.current_step = 0;

        // Set region
        const bc = std.mem.trim(u8, input.boundary_type, " ");
        if (std.mem.eql(u8, bc, "PBC")) {
            system.region = .{ .x = input.region_x, .y = input.region_y, .z = input.region_z };
            system.use_pbc = true;
        } else {
            system.region = .{ .x = 0, .y = 0, .z = 0 };
            system.use_pbc = false;
        }

        // Parse pos file
        var pos_file_name = std.mem.trim(u8, input.in_pos_file, " ");
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
        var mol_file_name = std.mem.trim(u8, input.in_mol_file, " ");
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

        var neighbor_list_cutoff: Real = 0.0;

        // --> Lennard-Jones interaction
        if (mol_file.lennard_jones_parameters.items.len > 0) {
            system.ff.lennard_jones_parameters = mol_file.lennard_jones_parameters.toOwnedSlice();
            try force_interactions.append(lennardJonesForceInteraction);
            try energy_interactions.append(lennardJonesEnergyInteraction);
            // Cutoff for neighbor list
            for (system.ff.lennard_jones_parameters) |para| {
                const cutoff = 2.5 * para.s + 0.3 * para.s;
                if (neighbor_list_cutoff < cutoff) neighbor_list_cutoff = cutoff;
            }
        }

        system.ff.force_interactions = force_interactions.toOwnedSlice();
        system.ff.energy_interactions = energy_interactions.toOwnedSlice();

        // Initialize neighbor list
        system.neighbor_list = NeighborList.init(allocator, neighbor_list_cutoff);
        system.neighbor_list_update_step = input.neighbor_list_step;
        try system.neighbor_list.update(&system);

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

        // Initialize temperature
        system.calculateTemperature();

        // Initialize integrator
        system.integrator = try Integrator.init(input);

        // Initialize files
        system.ts_file = try TsFile.init(input);
        system.ts_file_out = input.out_ts_step;
        try system.ts_file.printDataLine(&system);

        system.xyz_file = try XyzFile.init(input);
        system.xyz_file_out = input.out_xyz_step;
        try system.xyz_file.printDataFrame(&system);

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
        self.allocator.free(self.neighbor_list.pairs);
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

        // Calculate scaling factor
        var factor: Real = 0;
        for (self.v) |v, j| factor += self.m[j] * vec.dot(v, v);
        factor = 3.0 * @intToFloat(Real, self.v.len) * kb * temperature / factor;
        factor = std.math.sqrt(factor);

        // Scale velocities
        i = 0;
        while (i < self.v.len) : (i += 1) self.v[i] = vec.scale(self.v[i], factor);
    }

    pub fn calculateForceInteractions(self: *Self) void {
        // Reset forces
        var i: usize = 0;
        while (i < self.f.len) : (i += 1) {
            self.f[i] = Vec{ .x = 0.0, .y = 0.0, .z = 0.0 };
        }

        // Calculate forces
        for (self.ff.force_interactions) |f| f(self);
    }

    pub fn calculateEnergyInteractions(self: *Self) void {
        // Reset energy
        self.energy.potential = 0;

        // Calculate energy
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
        const dof = 3.0 * @intToFloat(Real, self.r.len);
        self.temperature = 2.0 * self.energy.kinetic / (dof * kb);
    }

    pub fn step(self: *Self) !void {
        // Update step counter
        self.current_step += 1;

        // Update neighbor list
        if (self.current_step % self.neighbor_list_update_step == 0) {
            self.neighbor_list.deinit();
            try self.neighbor_list.update(self);
        }

        // Integrate equations of motion
        self.integrator.evolveSystem(self);

        // Wrap system
        if (self.use_pbc) {
            var i: usize = 0;
            while (i < self.r.len) : (i += 1) {
                self.r[i] = vec.wrap(self.r[i], self.region);
            }
        }

        // Write ts file
        if (self.current_step % self.ts_file_out == 0) {
            // Calculate properties
            self.calculateEnergyInteractions();
            self.calculateKineticEnergy();
            self.calculateTemperature();
            // Report properties
            try self.ts_file.printDataLine(self);
        }

        // Write xyz file
        if (self.current_step % self.xyz_file_out == 0) {
            try self.xyz_file.printDataFrame(self);
        }
    }
};
