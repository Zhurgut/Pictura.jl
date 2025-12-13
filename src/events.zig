const std = @import("std");

const root = @import("root.zig");
const builtin = @import("builtin");

const sdl = root.sdl;

fn debug_mouse_pressed(x: f32, y: f32, button: u32) void {
    std.debug.print("mouse button {d} pressed at ({d}, {d})\n", .{ button, x, y });
}

fn debug_mouse_released(x: f32, y: f32, button: u32) void {
    std.debug.print("mouse button {d} released at ({d}, {d})\n", .{ button, x, y });
}

fn debug_mouse_wheel(vert: f32, hori: f32) void {
    std.debug.print("mouse wheel scrolled {d} vertically and {d} horizontally\n", .{ vert, hori });
}

fn debug_mouse_moved(x_prev: f32, y_prev: f32, x: f32, y: f32) void {
    std.debug.print("moved mouse from ({d}, {d}) to ({d}, {d})\n", .{ x_prev, y_prev, x, y });
}

fn debug_mouse_dragged(x_prev: f32, y_prev: f32, x: f32, y: f32) void {
    std.debug.print("dragged mouse from ({d}, {d}) to ({d}, {d})\n", .{ x_prev, y_prev, x, y });
}

fn debug_key_pressed(key: u8, shift: bool, ctrl: bool, alt: bool) void {
    const s = if (shift) "+shift" else "";
    const c = if (ctrl) "+ctrl" else "";
    const a = if (alt) "+alt" else "";
    std.debug.print("key {c}{s}{s}{s} pressed\n", .{ if (key < 128) key else ' ', s, c, a });
}

fn debug_key_released(key: u8, shift: bool, ctrl: bool, alt: bool) void {
    const s = if (shift) "+shift" else "";
    const c = if (ctrl) "+ctrl" else "";
    const a = if (alt) "+alt" else "";
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
        const buttons = sdl.SDL_GetMouseState(&x, &y);
        return .{ .x = x, .y = y, .buttons = [_]bool{
            false,
            (buttons & sdl.SDL_BUTTON_LMASK) != 0,
            (buttons & sdl.SDL_BUTTON_MMASK) != 0,
            (buttons & sdl.SDL_BUTTON_RMASK) != 0,
            (buttons & sdl.SDL_BUTTON_X1MASK) != 0,
            (buttons & sdl.SDL_BUTTON_X2MASK) != 0,
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
    mouse_pressed_fn: ?*const fn (x: f32, y: f32, button: u32) void = null,
    mouse_released_fn: ?*const fn (x: f32, y: f32, button: u32) void = null,
    mouse_wheel_fn: ?*const fn (vert: f32, hori: f32) void = null,
    mouse_moved_fn: ?*const fn (x_prev: f32, y_prev: f32, x: f32, y: f32) void = null,
    mouse_dragged_fn: ?*const fn (x_prev: f32, y_prev: f32, x: f32, y: f32) void = null,
    key_pressed_fn: ?*const fn (key: u8, shift: bool, ctrl: bool, alt: bool) void = null,
    key_released_fn: ?*const fn (key: u8, shift: bool, ctrl: bool, alt: bool) void = null,

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
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED, sdl.SDL_EVENT_WINDOW_DESTROYED, sdl.SDL_EVENT_QUIT => {
                    app.running = false;
                },
                sdl.SDL_EVENT_WINDOW_RESIZED, sdl.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED => {
                    const w = event.window.data1;
                    const h = event.window.data2;

                    std.debug.print("size changed {d} {d}\n", .{ w, h });

                    try app.resize(@intCast(w), @intCast(h));
                },
                sdl.SDL_EVENT_WINDOW_MOVED => {
                    const x = event.window.data1;
                    const y = event.window.data2;
                    std.debug.print("window moved to ({d},{d})\n", .{ x, y });
                },
                sdl.SDL_EVENT_KEY_DOWN => {
                    // const keycode = sdl.SDL_GetKeyFromScancode(event.key.scancode, event.key.mod, false);
                    const keycode = event.key.key;
                    const mod = event.key.mod;
                    const key = to_char(keycode);
                    const shift = ((mod & sdl.SDL_KMOD_SHIFT) == 0) != ((mod & sdl.SDL_KMOD_CAPS) == 0);
                    const ctrl = (mod & sdl.SDL_KMOD_CTRL) != 0;
                    const alt = (mod & sdl.SDL_KMOD_ALT) != 0;
                    if (key == 0) continue;
                    if (eh.key_pressed_fn) |f| {
                        f(key, shift, ctrl, alt);
                    }
                },
                sdl.SDL_EVENT_KEY_UP => {
                    // const keycode = sdl.SDL_GetKeyFromScancode(event.key.scancode, event.key.mod, false);
                    const keycode = event.key.key;
                    const mod = event.key.mod;
                    const key = to_char(keycode);
                    const shift = ((mod & sdl.SDL_KMOD_SHIFT) == 0) != ((mod & sdl.SDL_KMOD_CAPS) == 0);
                    const ctrl = (mod & sdl.SDL_KMOD_CTRL) != 0;
                    const alt = (mod & sdl.SDL_KMOD_ALT) != 0;
                    if (key == 0) continue;
                    if (eh.key_released_fn) |f| {
                        f(key, shift, ctrl, alt);
                    }
                },
                sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                    const x = event.button.x;
                    const y = event.button.y;
                    const b: sdl.SDL_MouseButtonFlags = event.button.button;
                    eh.mouse.buttons[b] = true;
                    if (eh.mouse_pressed_fn) |f| {
                        f(x, y, b);
                    }
                },
                sdl.SDL_EVENT_MOUSE_BUTTON_UP => {
                    const x = event.button.x;
                    const y = event.button.y;
                    const b: sdl.SDL_MouseButtonFlags = event.button.button;
                    eh.mouse.buttons[b] = false;
                    if (eh.mouse_released_fn) |f| {
                        f(x, y, b);
                    }
                },
                sdl.SDL_EVENT_WINDOW_MOUSE_ENTER => {},
                sdl.SDL_EVENT_WINDOW_MOUSE_LEAVE => {},
                sdl.SDL_EVENT_MOUSE_MOTION => {
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
                sdl.SDL_EVENT_MOUSE_WHEEL => {
                    const x = event.wheel.x;
                    const y = event.wheel.y;
                    if (eh.mouse_wheel_fn) |f| {
                        f(x, y);
                    }
                },
                else => {},
            }
        }
    }
};

fn to_char(keycode: sdl.SDL_Keycode) u8 {
    return switch (keycode) {
        sdl.SDLK_RETURN, sdl.SDLK_KP_ENTER => '\r',
        sdl.SDLK_BACKSPACE => 8, // aka '\b'
        sdl.SDLK_TAB => '\t',
        sdl.SDLK_SPACE => ' ',
        sdl.SDLK_KP_MULTIPLY => '*',
        sdl.SDLK_KP_PLUS => '+',
        sdl.SDLK_COMMA, sdl.SDLK_KP_COMMA => ',',
        sdl.SDLK_MINUS, sdl.SDLK_KP_MINUS => '-',
        sdl.SDLK_PERIOD, sdl.SDLK_KP_PERIOD => '.',
        sdl.SDLK_KP_DIVIDE => '/',
        sdl.SDLK_0, sdl.SDLK_KP_0 => '0',
        sdl.SDLK_1, sdl.SDLK_KP_1 => '1',
        sdl.SDLK_2, sdl.SDLK_KP_2 => '2',
        sdl.SDLK_3, sdl.SDLK_KP_3 => '3',
        sdl.SDLK_4, sdl.SDLK_KP_4 => '4',
        sdl.SDLK_5, sdl.SDLK_KP_5 => '5',
        sdl.SDLK_6, sdl.SDLK_KP_6 => '6',
        sdl.SDLK_7, sdl.SDLK_KP_7 => '7',
        sdl.SDLK_8, sdl.SDLK_KP_8 => '8',
        sdl.SDLK_9, sdl.SDLK_KP_9 => '9',
        sdl.SDLK_A => 'a',
        sdl.SDLK_B => 'b',
        sdl.SDLK_C => 'c',
        sdl.SDLK_D => 'd',
        sdl.SDLK_E => 'e',
        sdl.SDLK_F => 'f',
        sdl.SDLK_G => 'g',
        sdl.SDLK_H => 'h',
        sdl.SDLK_I => 'i',
        sdl.SDLK_J => 'j',
        sdl.SDLK_K => 'k',
        sdl.SDLK_L => 'l',
        sdl.SDLK_M => 'm',
        sdl.SDLK_N => 'n',
        sdl.SDLK_O => 'o',
        sdl.SDLK_P => 'p',
        sdl.SDLK_Q => 'q',
        sdl.SDLK_R => 'r',
        sdl.SDLK_S => 's',
        sdl.SDLK_T => 't',
        sdl.SDLK_U => 'u',
        sdl.SDLK_V => 'v',
        sdl.SDLK_W => 'w',
        sdl.SDLK_X => 'x',
        sdl.SDLK_Y => 'y',
        sdl.SDLK_Z => 'z',

        sdl.SDLK_DELETE => 127,

        // defined myself:
        sdl.SDLK_RIGHT => 128,
        sdl.SDLK_LEFT => 129,
        sdl.SDLK_DOWN => 130,
        sdl.SDLK_UP => 131,
        sdl.SDLK_LSHIFT, sdl.SDLK_RSHIFT => 132,
        sdl.SDLK_LCTRL, sdl.SDLK_RCTRL => 133,
        sdl.SDLK_LALT, sdl.SDLK_RALT => 134,

        sdl.SDLK_HOME => 135,
        sdl.SDLK_END => 136,
        sdl.SDLK_PAGEUP => 137,
        sdl.SDLK_PAGEDOWN => 138,
        sdl.SDLK_INSERT => 139,
        else => 0,
    };
}
