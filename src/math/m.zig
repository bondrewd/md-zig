const std = @import("std");
const Real = @import("../config.zig").Real;

pub const M = struct {
    xx: Real,
    xy: Real,
    xz: Real,

    yx: Real,
    yy: Real,
    yz: Real,

    zx: Real,
    zy: Real,
    zz: Real,

    const Self = @This();

    pub fn zeros() Self {
        return .{
            .xx = 0.0,
            .xy = 0.0,
            .xz = 0.0,

            .yx = 0.0,
            .yy = 0.0,
            .yz = 0.0,

            .zx = 0.0,
            .zy = 0.0,
            .zz = 0.0,
        };
    }

    pub fn ones() Self {
        return .{
            .xx = 1.0,
            .xy = 1.0,
            .xz = 1.0,

            .yx = 1.0,
            .yy = 1.0,
            .yz = 1.0,

            .zx = 1.0,
            .zy = 1.0,
            .zz = 1.0,
        };
    }

    pub fn eye() Self {
        return .{
            .xx = 1.0,
            .xy = 0.0,
            .xz = 0.0,

            .yx = 0.0,
            .yy = 1.0,
            .yz = 0.0,

            .zx = 0.0,
            .zy = 0.0,
            .zz = 1.0,
        };
    }
};

pub fn add(m1: M, m2: M) M {
    return .{
        .xx = m1.xx + m2.xx,
        .xy = m1.xy + m2.xy,
        .xz = m1.xz + m2.xz,

        .yx = m1.yx + m2.yx,
        .yy = m1.yy + m2.yy,
        .yz = m1.yz + m2.yz,

        .zx = m1.zx + m2.zx,
        .zy = m1.zy + m2.zy,
        .zz = m1.zz + m2.zz,
    };
}

pub fn sub(m1: M, m2: M) M {
    return .{
        .xx = m1.xx - m2.xx,
        .xy = m1.xy - m2.xy,
        .xz = m1.xz - m2.xz,

        .yx = m1.yx - m2.yx,
        .yy = m1.yy - m2.yy,
        .yz = m1.yz - m2.yz,

        .zx = m1.zx - m2.zx,
        .zy = m1.zy - m2.zy,
        .zz = m1.zz - m2.zz,
    };
}

pub fn mul(m1: M, m2: M) M {
    return .{
        .xx = m1.xx * m2.xx,
        .xy = m1.xy * m2.xy,
        .xz = m1.xz * m2.xz,

        .yx = m1.yx * m2.yx,
        .yy = m1.yy * m2.yy,
        .yz = m1.yz * m2.yz,

        .zx = m1.zx * m2.zx,
        .zy = m1.zy * m2.zy,
        .zz = m1.zz * m2.zz,
    };
}

pub fn div(m1: M, m2: M) M {
    return .{
        .xx = m1.xx / m2.xx,
        .xy = m1.xy / m2.xy,
        .xz = m1.xz / m2.xz,

        .yx = m1.yx / m2.yx,
        .yy = m1.yy / m2.yy,
        .yz = m1.yz / m2.yz,

        .zx = m1.zx / m2.zx,
        .zy = m1.zy / m2.zy,
        .zz = m1.zz / m2.zz,
    };
}

pub fn scale(m1: M, s: Real) M {
    return .{
        .xx = m1.xx * s,
        .xy = m1.xy * s,
        .xz = m1.xz * s,

        .yx = m1.yx * s,
        .yy = m1.yy * s,
        .yz = m1.yz * s,

        .zx = m1.zx * s,
        .zy = m1.zy * s,
        .zz = m1.zz * s,
    };
}

pub fn diagonal(m: M) [3]Real {
    return .{ m.xx, m.yy, m.zz };
}

pub fn transpose(m: M) M {
    return .{
        .xx = m.xx,
        .xy = m.yx,
        .xz = m.zx,

        .yx = m.xy,
        .yy = m.yy,
        .yz = m.zy,

        .zx = m.xz,
        .zy = m.yz,
        .zz = m.zz,
    };
}

pub fn det(m: M) Real {
    const a = m.xx * m.yy * m.zz + m.xy * m.yz * m.zx + m.xz * m.yx * m.zy;
    const b = m.xz * m.yy * m.zx + m.xy * m.yx * m.zz + m.xx * m.yz * m.zy;
    return a - b;
}

pub fn matMul(m1: M, m2: M) M {
    return .{
        .xx = m1.xx * m2.xx + m1.xy * m2.yx + m1.xz * m2.zx,
        .xy = m1.xx * m2.xy + m1.xy * m2.yy + m1.xz * m2.zy,
        .xz = m1.xx * m2.xz + m1.xy * m2.yz + m1.xz * m2.zz,

        .yx = m1.yx * m2.xx + m1.yy * m2.yx + m1.yz * m2.zx,
        .yy = m1.yx * m2.xy + m1.yy * m2.yy + m1.yz * m2.zy,
        .yz = m1.yx * m2.xz + m1.yy * m2.yz + m1.yz * m2.zz,

        .zx = m1.zx * m2.xx + m1.zy * m2.yx + m1.zz * m2.zx,
        .zy = m1.zx * m2.xy + m1.zy * m2.yy + m1.zz * m2.zy,
        .zz = m1.zx * m2.xz + m1.zy * m2.yz + m1.zz * m2.zz,
    };
}
