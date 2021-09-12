const std = @import("std");

const math = @import("math.zig");

const Real = @import("config.zig").Real;
const System = @import("system.zig").System;

pub const Pair = struct { i: u64, j: u64 };

pub const NeighborList = struct {
    allocator: *std.mem.Allocator,
    cutoff: Real,
    pairs: []Pair = &[_]Pair{},

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator, cutoff: Real) Self {
        return Self{ .allocator = allocator, .cutoff = cutoff };
    }

    pub fn update(self: *Self, system: *System) !void {
        // Deinit current list
        self.deinit();
        // Declare list for saving pairs
        var pairs = std.ArrayList(Pair).init(self.allocator);
        defer pairs.deinit();

        // Square of cutoff distance
        const cutoff2 = self.cutoff * self.cutoff;

        var i: usize = 0;
        while (i < system.r.items.len) : (i += 1) {
            const ri = system.r.items[i];

            var j: usize = i + 1;
            while (j < system.r.items.len) : (j += 1) {
                const rj = system.r.items[j];

                var rij = math.v.sub(ri, rj);
                if (system.use_pbc) rij = math.wrap(rij, system.region);
                const rij2 = math.v.dot(rij, rij);

                if (rij2 < cutoff2) try pairs.append(.{
                    .i = @intCast(u32, i),
                    .j = @intCast(u32, j),
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
