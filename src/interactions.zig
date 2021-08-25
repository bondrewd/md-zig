pub const LennardJonesInteraction = @import("interactions/lennard_jones.zig").LennardJonesInteraction;

pub const Interactions = struct {
    lennard_jones: ?[]LennardJonesInteraction = null,
};
