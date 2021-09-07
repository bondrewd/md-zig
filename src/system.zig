const std = @import("std");

const math = @import("math.zig");
const V3 = math.V3;
const M3x3 = math.M3x3;

const kb = @import("constant.zig").kb;
const Real = @import("config.zig").Real;
const TsFile = @import("file.zig").TsFile;
const XyzFile = @import("file.zig").XyzFile;
const PosFile = @import("file.zig").PosFile;
const MolFile = @import("file.zig").MolFile;
const VelFile = @import("file.zig").VelFile;
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
    r: []V3 = undefined,
    v: []V3 = undefined,
    f: []V3 = undefined,
    m: []Real = undefined,
    q: []Real = undefined,
    ff: ForceField = undefined,
    temperature: Real = undefined,
    virial: M3x3 = undefined,
    pressure: M3x3 = undefined,
    integrator: Integrator = undefined,
    energy: struct { kinetic: Real, potential: Real } = undefined,
    current_step: u64 = undefined,
    region: V3 = undefined,
    use_pbc: bool = undefined,
    neighbor_list: NeighborList = undefined,
    neighbor_list_update_step: u64 = undefined,

    ts_file: TsFile = undefined,
    ts_file_out: u64 = undefined,
    xyz_file: XyzFile = undefined,
    xyz_file_out: u64 = undefined,
    vel_file: VelFile = undefined,
    vel_file_out: u64 = undefined,

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
            system.region = V3.fromArray(.{ input.region_x, input.region_y, input.region_z });
            system.use_pbc = true;
        } else {
            system.region = V3.zeros();
            system.use_pbc = false;
        }

        // Parse pos file
        var pos_file_name = std.mem.trim(u8, input.in_pos_file, " ");
        var pos_file = PosFile.init(allocator);
        defer pos_file.deinit();
        try pos_file.openFile(pos_file_name, .{});
        try pos_file.load();

        // Initialize ids and positions
        system.id = pos_file.data.id.toOwnedSlice();
        system.r = pos_file.data.pos.toOwnedSlice();

        // Wrap system
        system.wrap();

        // Allocate velocity, force, mass, and charge
        system.v = try allocator.alloc(V3, system.r.len);
        system.f = try allocator.alloc(V3, system.r.len);
        system.m = try allocator.alloc(Real, system.r.len);
        system.q = try allocator.alloc(Real, system.r.len);

        // Parse mol file
        var mol_file_name = std.mem.trim(u8, input.in_mol_file, " ");
        var mol_file = MolFile.init(allocator);
        defer mol_file.deinit();
        try mol_file.openFile(mol_file_name, .{});
        try mol_file.load();

        // Initialize mass and charge
        system.m = mol_file.data.mass.toOwnedSlice();
        system.q = mol_file.data.charge.toOwnedSlice();

        // Initialize virial
        system.virial = M3x3.zeros();

        // Initialize pressure
        system.pressure = M3x3.zeros();

        // Initialize force field
        var force_interactions = std.ArrayList(fn (*Self) void).init(allocator);
        defer force_interactions.deinit();
        var energy_interactions = std.ArrayList(fn (*Self) void).init(allocator);
        defer energy_interactions.deinit();

        var neighbor_list_cutoff: Real = 0.0;

        // --> Lennard-Jones interaction
        if (mol_file.data.lj_parameters.items.len > 0) {
            system.ff.lennard_jones_parameters = mol_file.data.lj_parameters.toOwnedSlice();
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

        // Initialize pressure
        system.calculatePressure();

        // Initialize integrator
        system.integrator = try Integrator.init(input);

        // TS output file
        if (input.out_ts_step > 0) {
            var ts_file_name = std.mem.trim(u8, input.out_ts_file, " ");
            var ts_file = TsFile.init(allocator);
            try ts_file.createFile(ts_file_name, .{});
            try ts_file.printDataHeader();
            try ts_file.printDataFromSystem(&system);
            system.ts_file = ts_file;
            system.ts_file_out = input.out_ts_step;
        }

        // XYZ output file
        if (input.out_xyz_step > 0) {
            var xyz_file_name = std.mem.trim(u8, input.out_xyz_file, " ");
            var xyz_file = XyzFile.init(allocator);
            try xyz_file.createFile(xyz_file_name, .{});
            try xyz_file.printDataFromSystem(&system);
            system.xyz_file = xyz_file;
            system.xyz_file_out = input.out_xyz_step;
        }

        // Vel output file
        if (input.out_vel_step > 0) {
            var vel_file_name = std.mem.trim(u8, input.out_vel_file, " ");
            var vel_file = VelFile.init(allocator);
            try vel_file.createFile(vel_file_name, .{});
            try vel_file.printDataFromSystem(&system);
            system.vel_file = vel_file;
            system.vel_file_out = input.out_vel_step;
        }

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
        self.xyz_file.deinit();
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
            const a = V3.fromArray(.{
                std.math.sqrt(-2.0 * std.math.ln(rng.float(Real))),
                std.math.sqrt(-2.0 * std.math.ln(rng.float(Real))),
                std.math.sqrt(-2.0 * std.math.ln(rng.float(Real))),
            });

            // Beta
            const b = V3.fromArray(.{
                @cos(2.0 * std.math.pi * rng.float(Real)),
                @cos(2.0 * std.math.pi * rng.float(Real)),
                @cos(2.0 * std.math.pi * rng.float(Real)),
            });

            // Assign random velocity
            const ab = V3.mulVV(a, b);
            self.v[i] = V3.mulVS(ab, s);
        }

        // Calculate scaling factor
        var factor: Real = 0;
        for (self.v) |v, j| factor += self.m[j] * V3.dotVV(v, v);
        factor = 3.0 * @intToFloat(Real, self.v.len) * kb * temperature / factor;
        factor = std.math.sqrt(factor);

        // Scale velocities
        i = 0;
        while (i < self.v.len) : (i += 1) self.v[i] = V3.mulVS(self.v[i], factor);
    }

    pub fn calculateForceInteractions(self: *Self) void {
        // Reset forces
        var i: usize = 0;
        while (i < self.f.len) : (i += 1) {
            self.f[i] = V3.fromArray(.{ 0.0, 0.0, 0.0 });
        }

        // Reset virial
        self.virial = M3x3.zeros();

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
            energy += self.m[i] * V3.dotVV(self.v[i], self.v[i]);
        }

        self.energy.kinetic = 0.5 * energy;
    }

    pub fn calculateTemperature(self: *Self) void {
        self.calculateKineticEnergy();
        const dof = 3.0 * @intToFloat(Real, self.r.len);
        self.temperature = 2.0 * self.energy.kinetic / (dof * kb);
    }

    pub fn calculatePressure(self: *Self) void {
        // Calculate velocity tensor
        var v_tensor = M3x3.zeros();
        var i: usize = 0;
        while (i < self.v.len) : (i += 1) {
            const v = self.v[i];
            const m = self.m[i];
            const vv = V3.outerProductVV(v, v);
            const vvm = M3x3.mulMS(vv, m);
            v_tensor = M3x3.addMM(v_tensor, vvm);
        }

        // Calculate pressure
        const vol = self.region.items[0] * self.region.items[1] * self.region.items[2];
        const tmp = M3x3.addMM(v_tensor, self.virial);
        self.pressure = M3x3.divMS(tmp, vol);
    }

    pub fn wrap(self: *Self) void {
        if (self.use_pbc) {
            var i: usize = 0;
            while (i < self.r.len) : (i += 1) {
                self.r[i] = math.wrap(self.r[i], self.region);
            }
        }
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
        self.wrap();

        // Write ts file
        if (self.ts_file_out > 0 and self.current_step % self.ts_file_out == 0) {
            // Calculate properties
            self.calculateEnergyInteractions();
            self.calculateKineticEnergy();
            self.calculateTemperature();
            self.calculatePressure();
            // Report properties
            try self.ts_file.printDataFromSystem(self);
        }

        // Write xyz file
        if (self.xyz_file_out > 0 and self.current_step % self.xyz_file_out == 0) {
            try self.xyz_file.printDataFromSystem(self);
        }

        // Write vel file
        if (self.vel_file_out > 0 and self.current_step % self.vel_file_out == 0) {
            try self.vel_file.printDataFromSystem(self);
        }
    }
};
