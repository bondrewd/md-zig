const std = @import("std");
const Real = @import("../config.zig").Real;

const M = @import("m.zig").M;

pub const V = struct {
    x: Real,
    y: Real,
    z: Real,

    const Self = @This();

    pub fn zeros() Self {
        return .{ .x = 0.0, .y = 0.0, .z = 0.0 };
    }

    pub fn ones() Self {
        return .{ .x = 1.0, .y = 1.0, .z = 1.0 };
    }
};

pub fn add(v1: V, v2: V) V {
    return .{
        .x = v1.x + v2.x,
        .y = v1.y + v2.y,
        .z = v1.z + v2.z,
    };
}

pub fn sub(v1: V, v2: V) V {
    return .{
        .x = v1.x - v2.x,
        .y = v1.y - v2.y,
        .z = v1.z - v2.z,
    };
}

pub fn mul(v1: V, v2: V) V {
    return .{
        .x = v1.x * v2.x,
        .y = v1.y * v2.y,
        .z = v1.z * v2.z,
    };
}

pub fn div(v1: V, v2: V) V {
    return .{
        .x = v1.x / v2.x,
        .y = v1.y / v2.y,
        .z = v1.z / v2.z,
    };
}

pub fn scale(v: V, s: Real) V {
    return .{
        .x = v.x * s,
        .y = v.y * s,
        .z = v.z * s,
    };
}

pub fn dot(v1: V, v2: V) Real {
    return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z;
}

pub fn norm(v: V) Real {
    return std.math.sqrt(dot(v, v));
}

pub fn normalize(v: V) V {
    return scale(v, 1.0 / norm(v));
}

pub fn cross(v1: V, v2: V) V {
    const x = v1.y * v.z - v2.z * v.y;
    const y = v1.z * v.x - v2.x * v.z;
    const z = v1.x * v.y - v2.y * v.x;
    return .{ .x = x, .y = y, .z = z };
}

pub fn direct(v1: V, v2: V) M {
    return .{
        .xx = v1.x * v2.x,
        .xy = v1.x * v2.y,
        .xz = v1.x * v2.z,

        .yx = v1.y * v2.x,
        .yy = v1.y * v2.y,
        .yz = v1.y * v2.z,

        .zx = v1.z * v2.x,
        .zy = v1.z * v2.y,
        .zz = v1.z * v2.z,
    };
}
