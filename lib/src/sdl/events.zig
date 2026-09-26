const std = @import("std");

const root = @import("../root.zig");
const builtin = @import("builtin");

const sdl = root.sdl;

pub var keyboard: []const bool = undefined;

pub const DELETE = 127;
pub const RIGHT = 128;
pub const LEFT = 129;
pub const DOWN = 130;
pub const UP = 131;
pub const SHIFT = 132;
pub const CTRL = 133;
pub const ALT = 134;
pub const HOME = 135;
pub const END = 136;
pub const PAGEUP = 137;
pub const PAGEDOWN = 138;
pub const INSERT = 139;

fn debug_mouse_pressed(x: f32, y: f32, button: u32) callconv(.c) void {
    std.debug.print("mouse button {d} pressed at ({d}, {d})\n", .{ button, x, y });
}

fn debug_mouse_released(x: f32, y: f32, button: u32) callconv(.c) void {
    std.debug.print("mouse button {d} released at ({d}, {d})\n", .{ button, x, y });
}

fn debug_mouse_wheel(vert: f32, hori: f32) callconv(.c) void {
    std.debug.print("mouse wheel scrolled {d} vertically and {d} horizontally\n", .{ vert, hori });
}

fn debug_mouse_moved(x_prev: f32, y_prev: f32, x: f32, y: f32) callconv(.c) void {
    std.debug.print("moved mouse from ({d}, {d}) to ({d}, {d})\n", .{ x_prev, y_prev, x, y });
}

fn debug_mouse_dragged(x_prev: f32, y_prev: f32, x: f32, y: f32) callconv(.c) void {
    std.debug.print("dragged mouse from ({d}, {d}) to ({d}, {d})\n", .{ x_prev, y_prev, x, y });
}

fn debug_key_pressed(key: u8, shift: i32, ctrl: i32, alt: i32) callconv(.c) void {
    const s = if (shift != 0) "+shift" else "";
    const c = if (ctrl != 0) "+ctrl" else "";
    const a = if (alt != 0) "+alt" else "";
    std.debug.print("key {c}{s}{s}{s} pressed\n", .{ if (key < 128) key else ' ', s, c, a });
}

fn debug_key_released(key: u8, shift: i32, ctrl: i32, alt: i32) callconv(.c) void {
    const s = if (shift != 0) "+shift" else "";
    const c = if (ctrl != 0) "+ctrl" else "";
    const a = if (alt != 0) "+alt" else "";
    std.debug.print("key {c}{s}{s}{s} released\n", .{ if (key < 128) key else ' ', s, c, a });
}

pub const Mouse = struct {
    x: f32 = 0,
    y: f32 = 0,
    x_prev: f32 = 0,
    y_prev: f32 = 0,
    buttons: [6]bool = [6]bool{ false, false, false, false, false, false },

    pub fn init() Mouse {
        var x: f32 = undefined;
        var y: f32 = undefined;
        const buttons = sdl.c.SDL_GetMouseState(&x, &y);
        return .{ .x = x, .y = y, .buttons = [_]bool{
            false,
            (buttons & sdl.c.SDL_BUTTON_LMASK) != 0,
            (buttons & sdl.c.SDL_BUTTON_MMASK) != 0,
            (buttons & sdl.c.SDL_BUTTON_RMASK) != 0,
            (buttons & sdl.c.SDL_BUTTON_X1MASK) != 0,
            (buttons & sdl.c.SDL_BUTTON_X2MASK) != 0,
        } };
    }

    pub fn any_pressed(mouse: *Mouse) bool {
        for (mouse.buttons) |b| {
            if (b) {
                return true;
            }
        }
        return false;
    }
};

pub const EventHandler = struct {
    mouse: Mouse,
    mouse_pressed_fn: ?*const fn (x: f32, y: f32, button: u32) callconv(.c) void = null,
    mouse_released_fn: ?*const fn (x: f32, y: f32, button: u32) callconv(.c) void = null,
    mouse_wheel_fn: ?*const fn (vert: f32, hori: f32) callconv(.c) void = null,
    mouse_moved_fn: ?*const fn (x_prev: f32, y_prev: f32, x: f32, y: f32) callconv(.c) void = null,
    mouse_dragged_fn: ?*const fn (x_prev: f32, y_prev: f32, x: f32, y: f32) callconv(.c) void = null,
    key_pressed_fn: ?*const fn (key: u8, shift: i32, ctrl: i32, alt: i32) callconv(.c) void = null,
    key_released_fn: ?*const fn (key: u8, shift: i32, ctrl: i32, alt: i32) callconv(.c) void = null,

    pub fn create() EventHandler {
        if (builtin.mode == .Debug) {
            return .{
                .mouse = .init(),
                .mouse_pressed_fn = &debug_mouse_pressed,
                .mouse_released_fn = &debug_mouse_released,
                .mouse_wheel_fn = &debug_mouse_wheel,
                .mouse_moved_fn = &debug_mouse_moved,
                .mouse_dragged_fn = &debug_mouse_dragged,
                .key_pressed_fn = &debug_key_pressed,
                .key_released_fn = &debug_key_released,
            };
        }
        return .{
            .mouse = .init(),
        };
    }

    pub fn handle_events(eh: *EventHandler, app: *root.PicturaApp) !void {
        var event: sdl.c.SDL_Event = undefined;
        var new_w: ?u32 = null;
        var new_h: ?u32 = null;

        while (sdl.c.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.c.SDL_EVENT_WINDOW_CLOSE_REQUESTED, sdl.c.SDL_EVENT_WINDOW_DESTROYED, sdl.c.SDL_EVENT_QUIT => {
                    app.running = false;
                },
                sdl.c.SDL_EVENT_WINDOW_RESIZED, sdl.c.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED => {
                    new_w = @intCast(event.window.data1);
                    new_h = @intCast(event.window.data2);
                },
                sdl.c.SDL_EVENT_WINDOW_MOVED => {
                    const x = event.window.data1;
                    const y = event.window.data2;
                    std.debug.print("window moved to ({d},{d})\n", .{ x, y });
                },
                sdl.c.SDL_EVENT_KEY_DOWN => {
                    // const keycode = sdl.c.SDL_GetKeyFromScancode(event.key.scancode, event.key.mod, false);
                    const keycode = event.key.key;

                    switch (keycode) {
                        sdl.c.SDLK_F10 => {
                            // toggle border
                            const is_borderless = 0 != (sdl.c.SDL_GetWindowFlags(app.window) & sdl.c.SDL_WINDOW_BORDERLESS);
                            if (is_borderless) {
                                sdl.utils.set_bordered(app.window) catch {};
                            } else {
                                sdl.utils.set_borderless(app.window) catch {};
                            }
                        },
                        sdl.c.SDLK_F11 => {
                            // toggle fullscreen
                            const is_fullscreen = 0 != (sdl.c.SDL_GetWindowFlags(app.window) & sdl.c.SDL_WINDOW_FULLSCREEN);
                            if (is_fullscreen) {
                                sdl.utils.set_windowed(app.window) catch {};
                            } else {
                                sdl.utils.set_fullscreen(app.window) catch {};
                            }
                        },
                        sdl.c.SDLK_ESCAPE => {
                            app.running = false;
                        },
                        else => {
                            const mod = event.key.mod;
                            const key = to_char(keycode);
                            const shift = ((mod & sdl.c.SDL_KMOD_SHIFT) == 0) != ((mod & sdl.c.SDL_KMOD_CAPS) == 0);
                            const ctrl = (mod & sdl.c.SDL_KMOD_CTRL) != 0;
                            const alt = (mod & sdl.c.SDL_KMOD_ALT) != 0;
                            if (key == 0) continue;
                            if (eh.key_pressed_fn) |f| {
                                f(key, @intFromBool(shift), @intFromBool(ctrl), @intFromBool(alt));
                            }
                        },
                    }
                },
                sdl.c.SDL_EVENT_KEY_UP => {
                    // const keycode = sdl.c.SDL_GetKeyFromScancode(event.key.scancode, event.key.mod, false);
                    const keycode = event.key.key;
                    const mod = event.key.mod;
                    const key = to_char(keycode);
                    const shift = ((mod & sdl.c.SDL_KMOD_SHIFT) == 0) != ((mod & sdl.c.SDL_KMOD_CAPS) == 0);
                    const ctrl = (mod & sdl.c.SDL_KMOD_CTRL) != 0;
                    const alt = (mod & sdl.c.SDL_KMOD_ALT) != 0;
                    if (key == 0) continue;
                    if (eh.key_released_fn) |f| {
                        f(key, @intFromBool(shift), @intFromBool(ctrl), @intFromBool(alt));
                    }
                },
                sdl.c.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                    const x = event.button.x;
                    const y = event.button.y;
                    const b: sdl.c.SDL_MouseButtonFlags = event.button.button;
                    eh.mouse.buttons[b] = true;
                    if (eh.mouse_pressed_fn) |f| {
                        f(x, y, b);
                    }
                },
                sdl.c.SDL_EVENT_MOUSE_BUTTON_UP => {
                    const x = event.button.x;
                    const y = event.button.y;
                    const b: sdl.c.SDL_MouseButtonFlags = event.button.button;
                    eh.mouse.buttons[b] = false;
                    if (eh.mouse_released_fn) |f| {
                        f(x, y, b);
                    }
                },
                sdl.c.SDL_EVENT_WINDOW_MOUSE_ENTER => {},
                sdl.c.SDL_EVENT_WINDOW_MOUSE_LEAVE => {},
                sdl.c.SDL_EVENT_MOUSE_MOTION => {
                    const x = event.motion.x;
                    const y = event.motion.y;
                    const x_prev = x - event.motion.xrel;
                    const y_prev = y - event.motion.yrel;

                    eh.mouse.x = x;
                    eh.mouse.y = y;
                    eh.mouse.x_prev = x_prev;
                    eh.mouse.y_prev = y_prev;

                    if (eh.mouse.any_pressed()) {
                        if (eh.mouse_dragged_fn) |f| {
                            f(x_prev, y_prev, x, y);
                        }
                    }

                    if (eh.mouse_moved_fn) |f| {
                        f(x_prev, y_prev, x, y);
                    }
                },
                sdl.c.SDL_EVENT_MOUSE_WHEEL => {
                    const x = event.wheel.x;
                    const y = event.wheel.y;
                    if (eh.mouse_wheel_fn) |f| {
                        f(x, y);
                    }
                },
                else => {},
            }
        }

        if (new_w != null and new_w != null) {
            if (new_w.? != app.canvas.w or new_h.? != app.canvas.h) {
                std.debug.print("size changed {d} {d}\n", .{ new_w.?, new_h.? });
                try app.resize(new_w.?, new_h.?);
            }
        }

        if (app.swapchain.request_recreation) { // failsafe kindof
            try app.resize(app.canvas.w, app.canvas.h);
        }
    }
};

fn to_char(keycode: sdl.c.SDL_Keycode) u8 {
    return switch (keycode) {
        sdl.c.SDLK_RETURN, sdl.c.SDLK_KP_ENTER => '\r',
        sdl.c.SDLK_BACKSPACE => 8, // aka '\b'
        sdl.c.SDLK_TAB => '\t',
        sdl.c.SDLK_SPACE => ' ',
        sdl.c.SDLK_KP_MULTIPLY => '*',
        sdl.c.SDLK_KP_PLUS => '+',
        sdl.c.SDLK_COMMA, sdl.c.SDLK_KP_COMMA => ',',
        sdl.c.SDLK_MINUS, sdl.c.SDLK_KP_MINUS => '-',
        sdl.c.SDLK_PERIOD, sdl.c.SDLK_KP_PERIOD => '.',
        sdl.c.SDLK_KP_DIVIDE => '/',
        sdl.c.SDLK_0, sdl.c.SDLK_KP_0 => '0',
        sdl.c.SDLK_1, sdl.c.SDLK_KP_1 => '1',
        sdl.c.SDLK_2, sdl.c.SDLK_KP_2 => '2',
        sdl.c.SDLK_3, sdl.c.SDLK_KP_3 => '3',
        sdl.c.SDLK_4, sdl.c.SDLK_KP_4 => '4',
        sdl.c.SDLK_5, sdl.c.SDLK_KP_5 => '5',
        sdl.c.SDLK_6, sdl.c.SDLK_KP_6 => '6',
        sdl.c.SDLK_7, sdl.c.SDLK_KP_7 => '7',
        sdl.c.SDLK_8, sdl.c.SDLK_KP_8 => '8',
        sdl.c.SDLK_9, sdl.c.SDLK_KP_9 => '9',
        sdl.c.SDLK_A => 'a',
        sdl.c.SDLK_B => 'b',
        sdl.c.SDLK_C => 'c',
        sdl.c.SDLK_D => 'd',
        sdl.c.SDLK_E => 'e',
        sdl.c.SDLK_F => 'f',
        sdl.c.SDLK_G => 'g',
        sdl.c.SDLK_H => 'h',
        sdl.c.SDLK_I => 'i',
        sdl.c.SDLK_J => 'j',
        sdl.c.SDLK_K => 'k',
        sdl.c.SDLK_L => 'l',
        sdl.c.SDLK_M => 'm',
        sdl.c.SDLK_N => 'n',
        sdl.c.SDLK_O => 'o',
        sdl.c.SDLK_P => 'p',
        sdl.c.SDLK_Q => 'q',
        sdl.c.SDLK_R => 'r',
        sdl.c.SDLK_S => 's',
        sdl.c.SDLK_T => 't',
        sdl.c.SDLK_U => 'u',
        sdl.c.SDLK_V => 'v',
        sdl.c.SDLK_W => 'w',
        sdl.c.SDLK_X => 'x',
        sdl.c.SDLK_Y => 'y',
        sdl.c.SDLK_Z => 'z',

        sdl.c.SDLK_DELETE => DELETE,

        sdl.c.SDLK_RIGHT => RIGHT,
        sdl.c.SDLK_LEFT => LEFT,
        sdl.c.SDLK_DOWN => DOWN,
        sdl.c.SDLK_UP => UP,
        sdl.c.SDLK_LSHIFT, sdl.c.SDLK_RSHIFT => SHIFT,
        sdl.c.SDLK_LCTRL, sdl.c.SDLK_RCTRL => CTRL,
        sdl.c.SDLK_LALT, sdl.c.SDLK_RALT => ALT,

        sdl.c.SDLK_HOME => HOME,
        sdl.c.SDLK_END => END,
        sdl.c.SDLK_PAGEUP => PAGEUP,
        sdl.c.SDLK_PAGEDOWN => PAGEDOWN,
        sdl.c.SDLK_INSERT => INSERT,
        else => 0,
    };
}

fn to_keycode(key: u8, out_codes: [*]sdl.c.SDL_Keycode) usize {
    const keycodes: []const sdl.c.SDL_Keycode = switch (key) {
        '\r' => &[_]sdl.c.SDL_Keycode{ sdl.c.SDLK_RETURN, sdl.c.SDLK_KP_ENTER },
        8 => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_BACKSPACE},
        '\t' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_TAB},
        ' ' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_SPACE},
        '*' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_KP_MULTIPLY},
        '+' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_KP_PLUS},
        ',' => &[_]sdl.c.SDL_Keycode{ sdl.c.SDLK_COMMA, sdl.c.SDLK_KP_COMMA },
        '-' => &[_]sdl.c.SDL_Keycode{ sdl.c.SDLK_MINUS, sdl.c.SDLK_KP_MINUS },
        '.' => &[_]sdl.c.SDL_Keycode{ sdl.c.SDLK_PERIOD, sdl.c.SDLK_KP_PERIOD },
        '/' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_KP_DIVIDE},
        '0' => &[_]sdl.c.SDL_Keycode{ sdl.c.SDLK_0, sdl.c.SDLK_KP_0 },
        '1' => &[_]sdl.c.SDL_Keycode{ sdl.c.SDLK_1, sdl.c.SDLK_KP_1 },
        '2' => &[_]sdl.c.SDL_Keycode{ sdl.c.SDLK_2, sdl.c.SDLK_KP_2 },
        '3' => &[_]sdl.c.SDL_Keycode{ sdl.c.SDLK_3, sdl.c.SDLK_KP_3 },
        '4' => &[_]sdl.c.SDL_Keycode{ sdl.c.SDLK_4, sdl.c.SDLK_KP_4 },
        '5' => &[_]sdl.c.SDL_Keycode{ sdl.c.SDLK_5, sdl.c.SDLK_KP_5 },
        '6' => &[_]sdl.c.SDL_Keycode{ sdl.c.SDLK_6, sdl.c.SDLK_KP_6 },
        '7' => &[_]sdl.c.SDL_Keycode{ sdl.c.SDLK_7, sdl.c.SDLK_KP_7 },
        '8' => &[_]sdl.c.SDL_Keycode{ sdl.c.SDLK_8, sdl.c.SDLK_KP_8 },
        '9' => &[_]sdl.c.SDL_Keycode{ sdl.c.SDLK_9, sdl.c.SDLK_KP_9 },
        'a' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_A},
        'b' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_B},
        'c' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_C},
        'd' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_D},
        'e' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_E},
        'f' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_F},
        'g' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_G},
        'h' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_H},
        'i' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_I},
        'j' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_J},
        'k' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_K},
        'l' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_L},
        'm' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_M},
        'n' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_N},
        'o' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_O},
        'p' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_P},
        'q' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_Q},
        'r' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_R},
        's' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_S},
        't' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_T},
        'u' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_U},
        'v' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_V},
        'w' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_W},
        'x' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_X},
        'y' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_Y},
        'z' => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_Z},
        DELETE => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_DELETE},
        RIGHT => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_RIGHT},
        LEFT => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_LEFT},
        DOWN => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_DOWN},
        UP => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_UP},
        SHIFT => &[_]sdl.c.SDL_Keycode{ sdl.c.SDLK_LSHIFT, sdl.c.SDLK_RSHIFT },
        CTRL => &[_]sdl.c.SDL_Keycode{ sdl.c.SDLK_LCTRL, sdl.c.SDLK_RCTRL },
        ALT => &[_]sdl.c.SDL_Keycode{ sdl.c.SDLK_LALT, sdl.c.SDLK_RALT },
        HOME => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_HOME},
        END => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_END},
        PAGEUP => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_PAGEUP},
        PAGEDOWN => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_PAGEDOWN},
        INSERT => &[_]sdl.c.SDL_Keycode{sdl.c.SDLK_INSERT},
        else => &[_]sdl.c.SDL_Keycode{0},
    };

    @memmove(out_codes, keycodes);
    return keycodes.len;
}

pub fn is_key_pressed(key: u8) bool {
    var key_codes_buf = [3]sdl.c.SDL_Keycode{ 0, 0, 0 };
    const l = to_keycode(key, &key_codes_buf);
    const key_codes = key_codes_buf[0..l];

    var pressed = false;
    for (key_codes) |k| {
        const scancode = sdl.c.SDL_GetScancodeFromKey(k, null);
        pressed |= keyboard[scancode];
    }

    return pressed;
}
