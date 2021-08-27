const std = @import("std");

const System = @import("system.zig").System;
const Reporter = @import("reporter.zig").Reporter;
const ProgressBar = @import("progress_bar.zig").ProgressBar;
const MdInputParser = @import("input.zig").MdInputParser;

const argparse = @import("argparse-zig/src/argparse.zig");
const ArgumentParser = argparse.ArgumentParser;
const ArgumentParserOption = argparse.ArgumentParserOption;

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = &arena.allocator;

    const args = try ArgParser.parse(allocator);
    defer ArgParser.deinitArgs(args);

    const input = try MdInputParser.parse(allocator, args.input);
    defer MdInputParser.deinit(allocator, input);

    var system = try System.init(.{
        .allocator = allocator,
        .integrator = input.integrator,
        .time_step = input.time_step,
        .rng_seed = input.rng_seed,
    });

    try system.initPositions(input.pos_file);
    try system.initForceField(input.mol_file);
    system.initVelocities(input.temperature);

    const of_name = std.mem.trim(u8, input.out_ts_name, " ");
    const of = try std.fs.cwd().createFile(of_name, .{});
    const ow = of.writer();
    const reporter = Reporter.init(&system);

    system.updateEnergy();
    try reporter.writeHeader(ow);
    try reporter.report(ow, 0);

    const stdout = std.io.getStdOut().writer();
    const progress_bar = ProgressBar.init(stdout, .{});

    var istep: usize = 1;
    while (istep <= input.n_steps) : (istep += 1) {
        system.integrate();
        try progress_bar.displayProgress(istep, 1, input.n_steps);

        if (input.out_ts_step > 0 and istep % input.out_ts_step == 0) {
            system.updateEnergy();
            try reporter.report(ow, istep);
        }
    }
}

const ArgParser = ArgumentParser(.{
    .bin_name = "md",
    .bin_info = "Molecular Dynamics software.",
    .bin_usage = "./md OPTION [OPTION...]",
    .bin_version = .{ .major = 0, .minor = 1, .patch = 0 },
    .display_error = true,
}, [_]ArgumentParserOption{
    .{
        .name = "input",
        .long = "--input",
        .short = "-i",
        .description = "Input file name (Required)",
        .metavar = "<FILE>",
        .argument_type = []const u8,
        .takes = .One,
        .required = true,
    },
});
