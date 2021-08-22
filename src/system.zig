const std = @import("std");
const vec = @import("vec.zig");
const Vec = @import("vec.zig").Vec;
const Real = @import("config.zig").Real;
const ansi = @import("ansi-zig/src/ansi.zig");

// Ansi format
const reset = ansi.reset;
const bold = ansi.bold_on;
const blue = ansi.fg_light_blue;
const yellow = ansi.fg_light_yellow;

pub const Atom = struct {
    r: Vec = .{},
    v: Vec = .{},
    a: Vec = .{},
};

pub const System = struct {
    dt: Real = undefined,
    region: Vec = undefined,
    cell: [3]u64 = undefined,
    energy: Energy = undefined,
    atoms: std.ArrayList(Atom) = undefined,
    target_temperature: Real = undefined,
    temperature: Real = undefined,

    const Energy = struct {
        kinetic: Real = 0,
        potential: Real = 0,
        total: Real = 0,
    };

    const Self = @This();

    const Configuration = struct {
        dt: Real,
        cell: [3]u64,
        density: Real,
        temperature: Real,
    };

    pub fn init(allocator: *std.mem.Allocator, config: Configuration) !Self {
        var system = System{};

        system.dt = config.dt;
        system.target_temperature = config.temperature;
        system.cell[0] = config.cell[0];
        system.cell[1] = config.cell[1];
        system.cell[2] = config.cell[2];

        const linear_density = std.math.pow(Real, config.density, 1.0 / 3.0);

        system.region.x = @intToFloat(Real, config.cell[0]) * linear_density;
        system.region.y = @intToFloat(Real, config.cell[1]) * linear_density;
        system.region.z = @intToFloat(Real, config.cell[2]) * linear_density;

        try system.initAtoms(allocator);

        system.updateEnergies();

        return system;
    }

    pub fn deinit(self: Self) void {
        self.atoms.deinit();
    }

    pub fn addAtoms(self: *Self) !void {
        var i: usize = 0;
        const n_atoms = self.cell[0] * self.cell[1] * self.cell[2];
        while (i < n_atoms) : (i += 1) {
            try self.atoms.append(Atom{});
        }
    }

    pub fn initPositions(self: *Self) void {
        const cell = self.cell;
        const region = self.region;

        const delta = Vec{
            .x = region.x / @intToFloat(Real, cell[0]),
            .y = region.y / @intToFloat(Real, cell[1]),
            .z = region.z / @intToFloat(Real, cell[2]),
        };

        var iz: usize = 0;
        while (iz < cell[2]) : (iz += 1) {
            var iy: usize = 0;
            while (iy < cell[1]) : (iy += 1) {
                var ix: usize = 0;
                while (ix < cell[0]) : (ix += 1) {
                    const iatom = ix + iy * cell[0] + iz * cell[0] * cell[1];

                    self.atoms.items[iatom].r = Vec{
                        .x = -0.5 * region.x + (@intToFloat(Real, ix) + 0.5) * delta.x,
                        .y = -0.5 * region.y + (@intToFloat(Real, iy) + 0.5) * delta.y,
                        .z = -0.5 * region.z + (@intToFloat(Real, iz) + 0.5) * delta.z,
                    };
                }
            }
        }
    }

    pub fn initVelocities(self: *Self) !void {
        // Initialize random number generator
        var prng = std.rand.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            try std.os.getrandom(std.mem.asBytes(&seed));
            break :blk seed;
        });
        const rand = &prng.random;

        // Initialize local variables
        var v_sum = Vec{};
        const n_atoms = @intToFloat(Real, self.atoms.items.len);
        const velocity = std.math.sqrt(3.0 * (1.0 - 1.0 / n_atoms) * self.target_temperature);

        // Initialize with random velocities
        for (self.atoms.items) |*atom| {
            // Create a random unit vector
            var v_random = Vec{ .x = rand.float(Real), .y = rand.float(Real), .z = rand.float(Real) };
            v_random = vec.normalize(v_random);

            // Assign random velocity
            atom.v = vec.scale(v_random, velocity);
            v_sum = vec.add(v_sum, atom.v);
        }

        // Calculate system velocity
        const v_avg = vec.scale(v_sum, 1.0 / n_atoms);

        // Remove system velocity
        for (self.atoms.items) |*atom| {
            atom.v = vec.sub(atom.v, v_avg);
        }
    }

    pub fn initAccelerations(self: *Self) void {
        for (self.atoms.items) |*atom| {
            atom.a = Vec{};
        }
    }

    pub fn initAtoms(self: *Self, allocator: *std.mem.Allocator) !void {
        // Allocate atoms
        self.atoms = std.ArrayList(Atom).init(allocator);
        try self.addAtoms();

        // Init positions
        self.initPositions();

        // Init velocities
        try self.initVelocities();

        // Init accelerations
        self.initAccelerations();
    }

    pub fn updateKineticEnergy(self: *Self) void {
        var kinetic: Real = 0.0;
        for (self.atoms.items) |atom| {
            kinetic += vec.dot(atom.v, atom.v);
        }

        self.temperature = kinetic / (3.0 * (@intToFloat(Real, self.atoms.items.len) - 1.0));
        self.energy.kinetic = 0.5 * kinetic;
    }

    pub fn updatePotentialEnergy(self: *Self) void {
        const rr_cut = std.math.pow(Real, 2.0, 1.0 / 3.0);
        var potential: Real = 0.0;

        var i: usize = 0;
        while (i < self.atoms.items.len) : (i += 1) {
            const iatom = self.atoms.items[i];

            var j: usize = i + 1;
            while (j < self.atoms.items.len) : (j += 1) {
                const jatom = self.atoms.items[j];

                var rij: Vec = undefined;
                rij = vec.sub(iatom.r, jatom.r);
                rij = vec.wrap(rij, self.region);

                const rr = vec.dot(rij, rij);
                if (rr < rr_cut) {
                    const rri = 1.0 / rr;
                    const rri3 = rri * rri * rri;
                    potential += 4.0 * rri3 * (rri3 - 1.0) + 1.0;
                }
            }
        }

        self.energy.potential = potential;
    }

    pub fn updateEnergies(self: *Self) void {
        self.updateKineticEnergy();
        self.updatePotentialEnergy();
        self.energy.total = self.energy.kinetic + self.energy.potential;
    }

    pub fn calculateForces(self: *Self) void {
        const rr_cut = std.math.pow(Real, 2.0, 1.0 / 3.0);

        for (self.atoms.items) |*atom| {
            atom.a.x = 0.0;
            atom.a.y = 0.0;
            atom.a.z = 0.0;
        }

        var i: usize = 0;
        while (i < self.atoms.items.len) : (i += 1) {
            const iatom = self.atoms.items[i];

            var j: usize = i + 1;
            while (j < self.atoms.items.len) : (j += 1) {
                const jatom = self.atoms.items[j];

                var rij: Vec = undefined;
                rij = vec.sub(iatom.r, jatom.r);
                rij = vec.wrap(rij, self.region);

                const rr = vec.dot(rij, rij);
                if (rr < rr_cut) {
                    const rri = 1.0 / rr;
                    const rri3 = rri * rri * rri;
                    const f = 48.0 * rri3 * (rri3 - 0.5) * rri;
                    const force = vec.scale(rij, f);

                    self.atoms.items[i].a = vec.add(self.atoms.items[i].a, force);
                    self.atoms.items[j].a = vec.sub(self.atoms.items[j].a, force);
                }
            }
        }
    }

    pub fn step(self: *Self) void {
        for (self.atoms.items) |*atom| {
            atom.v = vec.add(atom.v, vec.scale(atom.a, self.dt / 2.0));
            atom.r = vec.add(atom.r, vec.scale(atom.v, self.dt));
            self.calculateForces();
            atom.v = vec.add(atom.v, vec.scale(atom.a, self.dt / 2.0));
        }
    }

    pub fn displayInfo(self: Self) !void {
        // Get stdout
        const stdout = std.io.getStdOut().writer();

        // Print header
        try stdout.writeAll(bold ++ yellow ++ "> SYSTEM:\n" ++ reset);
        // Print values
        try stdout.print(bold ++ blue ++ "    Total:        " ++ reset ++ "{e:<12.5}\n", .{self.energy.total});
        try stdout.print(bold ++ blue ++ "      Kinetic:    " ++ reset ++ "{e:<12.5}\n", .{self.energy.kinetic});
        try stdout.print(bold ++ blue ++ "      Potential:  " ++ reset ++ "{e:<12.5}\n", .{self.energy.potential});
        try stdout.print(bold ++ blue ++ "    Region:       " ++ reset ++ "{d:<8.3} {d:<8.3} {d:<8.3}\n", .{ self.region.x, self.region.y, self.region.z });
        try stdout.print(bold ++ blue ++ "    Particles:    " ++ reset ++ "{d:<8}\n", .{self.atoms.items.len});
    }
};
