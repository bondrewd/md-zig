const Vec = @import("vec.zig").Vec;
const Real = @import("config.zig").Real;

pub const Atom = struct {
    r: Vec = .{},
    v: Vec = .{},
    f: Vec = .{},
    m: Real = undefined,
    id: u64 = undefined,
};
