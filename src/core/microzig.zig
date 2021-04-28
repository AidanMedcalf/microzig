const std = @import("std");
const root = @import("root");

/// Contains build-time generated configuration options for microzig.
/// Contains a CPU target description, chip, board and cpu information
/// and so on.
pub const config = @import("microzig-config");

/// Provides access to the low level features of the current microchip.
pub const chip = @import("chip");

/// Provides access to the low level features of the CPU.
pub const cpu = chip.cpu;

/// Module that helps with interrupt handling.
pub const interrupts = @import("interrupts.zig");

const gpio = @import("gpio.zig");
pub const Gpio = gpio.Gpio;

const pin = @import("pin.zig");
pub const Pin = pin.Pin;

/// The microzig panic handler. Will disable interrupts and loop endlessly.
/// Export this symbol from your main file to enable microzig:
/// ```
/// const micro = @import("microzig");
/// pub const panic = micro.panic;
/// ```
pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    hang();
}

/// Hangs the processor and will stop doing anything useful. Use with caution!
pub fn hang() noreturn {
    while (true) {
        interrupts.cli();

        // "this loop has side effects, don't optimize the endless loop away please. thanks!"
        asm volatile ("" ::: "memory");
    }
}

/// This is the logical entry point for microzig.
/// It will invoke the main function from the root source file
/// and provides error return handling as well as a event loop if requested.
///
/// Why is this function exported?
/// This is due to the modular design of microzig to allow the "chip" dependency of microzig
/// to call into our main function here. If we would use a normal function call, we'd have a
/// circular dependency between the `microzig` and `chip` package. This function is also likely
/// to be invoked from assembly, so it's also convenient in that regard.
export fn microzig_main() noreturn {
    if (!@hasDecl(root, "main"))
        @compileError("The root source file must provide a public function main!");

    const main = @field(root, "main");
    const info: std.builtin.TypeInfo = @typeInfo(@TypeOf(main));

    const invalid_main_msg = "main must be either 'pub fn main() void' or 'pub fn main() !void'.";
    if (info != .Fn or info.Fn.args.len > 0)
        @compileError(invalid_main_msg);

    const return_type = info.Fn.return_type orelse @compileError(invalid_main_msg);

    if (info.Fn.calling_convention == .Async)
        @compileError("TODO: Embedded event loop not supported yet. Please try again later.");

    if (@typeInfo(return_type) == .ErrorUnion) {
        main() catch |err| {
            // TODO:
            // - Compute maximum size on the type of "err"
            // - Do not emit error names when std.builtin.strip is set.
            var msg: [64]u8 = undefined;
            @panic(std.fmt.bufPrint(&msg, "main() returned error {s}", .{@tagName(err)}) catch @panic("main() returned error."));
        };
    } else {
        main();
    }

    // main returned, just hang around here a bit
    hang();
}

comptime {
    _ = cpu.startup_logic;
}
