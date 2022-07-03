const std = @import("std");
const micro = @import("microzig.zig");
const chip = @import("chip");
const board = @import("board");

/// Returns a type that will manage the Pin defined by `spec`.
/// Spec is either the pin as named in the datasheet of the chip
/// or, if a board is present, as named on the board.
///
/// When a name conflict happens, pin names can be prefixed with `board:`
/// to force-select a pin from the board and with `chip:` to force-select
/// the pin from the chip.
pub fn Pin(comptime spec: []const u8) type {
    // TODO: Depened on board and chip here

    const board_namespace = "board:";
    const chip_namespace = "chip:";

    // Pins can be namespaced with "board:" for board and "chip:" for chip
    // These namespaces are not passed to chip.parsePin
    const pin = if (std.mem.startsWith(u8, spec, board_namespace))
        chip.parsePin(@field(board.pin_map, spec[board_namespace.len..]))
    else if (std.mem.startsWith(u8, spec, chip_namespace))
        chip.parsePin(spec[chip_namespace.len..])
    else if (micro.config.has_board and @hasField(@TypeOf(board.pin_map), spec))
        chip.parsePin(@field(board.pin_map, spec))
    else
        chip.parsePin(spec);

    return struct {
        pub const name = if (std.mem.startsWith(u8, spec, board_namespace.len))
            // Remove the board: prefix
            spec[board_namespace.len..]
        else if (std.mem.startsWith(u8, spec, chip_namespace))
            // Remove the chip: prefix
            spec[chip_namespace.len..]
        else
            spec;

        pub const source_pin = pin;

        pub fn route(target: pin.Targets) void {
            chip.routePin(source_pin, target);
        }
    };
}
