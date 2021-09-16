const std = @import("std");

const Input = @import("input.zig").Input;

const LennardJonesNeighborList = @import("neighbor_list/lj_neighbor_list.zig").LennardJonesNeighborList;

const Allocator = std.mem.Allocator;

pub const NeighborList = struct {
    lj_list: LennardJonesNeighborList,

    const Self = @This();

    pub fn init(allocator: *Allocator, input: Input) !Self {
        return Self{
            .lj_list = try LennardJonesNeighborList.init(allocator, input),
        };
    }

    pub fn deinit(self: Self) void {
        self.lj_list.deinit();
    }

    pub fn update(self: *Self, r: []V, box: ?V) !void {
        try self.lj_list.update(r, box);
    }
};
