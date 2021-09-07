const std = @import("std");

const math = @import("math.zig");
const V3 = math.V3;

const Real = @import("config.zig").Real;
const System = @import("system.zig").System;

pub const Pair = struct { i: u64, j: u64 };

pub const NeighborList = struct {
    allocator: *std.mem.Allocator,
    cutoff: Real,
    pairs: []Pair = undefined,

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator, cutoff: Real) Self {
        return Self{ .allocator = allocator, .cutoff = cutoff };
    }

    pub fn update(self: *Self, system: *System) !void {
        // Declare list for saving pairs
        var pairs = std.ArrayList(Pair).init(self.allocator);
        defer pairs.deinit();

        // Square of cutoff distance
        const cutoff2 = self.cutoff * self.cutoff;

        var i: usize = 0;
        while (i < system.r.len) : (i += 1) {
            const ri = system.r[i];

            var j: usize = i + 1;
            while (j < system.r.len) : (j += 1) {
                const rj = system.r[j];

                var rij = V3.subVV(ri, rj);
                if (system.use_pbc) rij = math.wrap(rij, system.region);
                const rij2 = V3.dotVV(rij, rij);

                if (rij2 < cutoff2) try pairs.append(.{
                    .i = @intCast(u64, i),
                    .j = @intCast(u64, j),
                });
            }
        }

        // Save neighbor list
        self.pairs = pairs.toOwnedSlice();
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.pairs);
    }
};
