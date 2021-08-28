const std = @import("std");
const System = @import("system.zig").System;
const MdInputFileParser = @import("input.zig").MdInputFileParser;

pub fn main() anyerror!void {
    // Get allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = &arena.allocator;

    // Parse arguments
    const args = try ArgParser.parse(allocator);
    defer ArgParser.deinitArgs(args);

    // Parse input file
    const input = try MdInputFileParser.parse(allocator, args.input);
    defer MdInputFileParser.deinitInput(allocator, input);

    // Init system
    var system = try System.init(allocator, input);
    defer system.deinit();

    // Perform MD
    var istep: usize = 1;
    while (istep <= input.n_steps) : (istep += 1) {
        try system.step();
    }
}

// Argument parser
const argparse = @import("argparse-zig/src/argparse.zig");
const ArgumentParser = argparse.ArgumentParser;
const ArgumentParserOption = argparse.ArgumentParserOption;

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
