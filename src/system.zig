const std = @import("std");
const vec = @import("vec.zig");
const Vec = @import("vec.zig").Vec;
const Atom = @import("atom.zig").Atom;
const Real = @import("config.zig").Real;
const PosFile = @import("file.zig").PosFile;
const stopWithErrorMsg = @import("exception.zig").stopWithErrorMsg;
const integratorFromString = @import("integrator.zig").integratorFromString;

const kb = @import("constant.zig").kb;

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

    pub fn initPositionsFromPosFile(self: *Self, file_name: []const u8) !void {
        const pos_file = try PosFile(.{}).init(self.allocator, file_name);
        defer pos_file.deinit();

        self.atoms = try self.allocator.alloc(Atom, pos_file.len);
        for (self.atoms) |*atom, i| {
            atom.r.x = pos_file.pos[i].x;
            atom.r.y = pos_file.pos[i].y;
            atom.r.z = pos_file.pos[i].z;
            atom.id = pos_file.id[i];
        }
    }

    pub fn initPositions(self: *Self, file_name: []const u8) !void {
        // Trim string
        const file_name_trim = std.mem.trim(u8, file_name, " ");

        // Find extension
        var tokens = std.mem.tokenize(u8, file_name_trim, ".");
        var ext: ?[]const u8 = null;
        while (tokens.rest().len != 0) ext = tokens.next();

        // Parse extension
        if (ext) |e| {
            if (std.mem.eql(u8, e, "pos")) {
                try self.initPositionsFromPosFile(file_name_trim);
            } else {
                try stopWithErrorMsg("Unknown position file extension -> {s}", .{e});
            }
        } else {
            try stopWithErrorMsg("Can't infer file type from extension -> {s}", .{file_name_trim});
        }
    }

    pub fn initVelocities(self: *Self, temperature: Real) void {
        // Get rng
        const rand = &self.random.rng.random;

        // Initialize with random velocities
        for (self.atoms) |*atom| {
            // Sigma
            // TODO: Mass is currently hard-coded
            const s = std.math.sqrt(kb * temperature / 39.948);

            // Alpha
            const a = Vec{
                .x = std.math.sqrt(-2.0 * std.math.ln(rand.float(Real))),
                .y = std.math.sqrt(-2.0 * std.math.ln(rand.float(Real))),
                .z = std.math.sqrt(-2.0 * std.math.ln(rand.float(Real))),
            };

            // Beta
            const b = Vec{
                .x = @cos(2.0 * std.math.pi * rand.float(Real)),
                .y = @cos(2.0 * std.math.pi * rand.float(Real)),
                .z = @cos(2.0 * std.math.pi * rand.float(Real)),
            };

            // Assign random velocity
            atom.v = vec.scale(vec.mul(a, b), s);
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
