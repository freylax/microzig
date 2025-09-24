const mmio = @import("mmio");
const std = @import("std");
const microzig = @import("microzig");
const peripherals = microzig.chip.peripherals;
const USART0 = peripherals.USART0;

pub const cpu = microzig.cpu;
const Port = enum(u8) {
    A = 1,
    B = 2,
};

pub const clock = struct {
    pub const Domain = enum {
        cpu,
    };
};

pub fn parse_pin(comptime spec: []const u8) type {
    const invalid_format_msg = "The given pin '" ++ spec ++ "' has an invalid format. Pins must follow the format \"P{Port}{Pin}\" scheme.";

    if (spec.len != 3)
        @compileError(invalid_format_msg);
    if (spec[0] != 'P')
        @compileError(invalid_format_msg);
    const pin = struct {
        pub const port: Port = std.meta.stringToEnum(Port, spec[1..2]) orelse @compileError(invalid_format_msg);
        pub const pin: u3 = std.fmt.parseInt(u3, spec[2..3], 10) catch @compileError(invalid_format_msg);
    };
    return pin;
}

pub const gpio = struct {
    fn regs(comptime desc: type) type {
        return struct {
            // io address
            const pin_addr: u5 = 3 * @intFromEnum(desc.port) + 0x00;
            const dir_addr: u5 = 3 * @intFromEnum(desc.port) + 0x01;
            const port_addr: u5 = 3 * @intFromEnum(desc.port) + 0x02;

            // ram mapping
            const pin = @as(*volatile u8, @ptrFromInt(0x20 + @as(usize, pin_addr)));
            const dir = @as(*volatile u8, @ptrFromInt(0x20 + @as(usize, dir_addr)));
            const port = @as(*volatile u8, @ptrFromInt(0x20 + @as(usize, port_addr)));
        };
    }

    pub fn set_output(comptime pin: type) void {
        cpu.sbi(regs(pin).dir_addr, pin.pin);
    }

    pub fn set_input(comptime pin: type) void {
        cpu.cbi(regs(pin).dir_addr, pin.pin);
    }

    pub fn read(comptime pin: type) microzig.core.experimental.gpio.State {
        return if ((regs(pin).pin.* & (1 << pin.pin)) != 0)
            .high
        else
            .low;
    }

    pub fn write(comptime pin: type, state: microzig.core.experimental.gpio.State) void {
        switch (state) {
            .high => cpu.sbi(regs(pin).port_addr, pin.pin),
            .low => cpu.cbi(regs(pin).port_addr, pin.pin),
        }
    }

    pub fn toggle(comptime pin: type) void {
        cpu.sbi(regs(pin).pin_addr, pin.pin);
    }
};
