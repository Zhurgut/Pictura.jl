
module Callbacks

import ..Pictura
using PicturaShapes

export @mousepressed ,@mousereleased, @mousemoved, @mousedragged, @mousewheel, @keypressed, @keyreleased

const on_mouse_pressed::Ref{Function} = Ref{Function}((BUTTON) -> println("mouse pressed $(Pictura.mouse().x)"))
const on_mouse_released::Ref{Function} = Ref{Function}((BUTTON) -> nothing)
const on_mouse_wheel::Ref{Function} = Ref{Function}((WHEEL) -> nothing)
const on_mouse_moved::Ref{Function} = Ref{Function}(() -> nothing)
const on_mouse_dragged::Ref{Function} = Ref{Function}(() -> nothing)
const on_key_pressed::Ref{Function} = Ref{Function}((k, s, c, a) -> println("key pressed $(Char(k))"))
const on_key_released::Ref{Function} = Ref{Function}((k, s, c, a) -> nothing)

function mouse_pressed_fn(x::Float32, y::Float32, button::UInt32)
    m = Pictura.app.mouse
    l,md,r = m.l || button == 1, m.m || button == 2, m.r || button == 3
    Pictura.app.mouse = (l=l, m=md, r=r, x=x, y=y, pos=Point(x, y), prev=m.prev)
    BUTTON = button # for now, TODO make a new type so we can compare BUTTON == "left", BUTTON == :l, etc.
    on_mouse_pressed[](BUTTON)
    nothing
end

function mouse_released_fn(x::Float32, y::Float32, button::UInt32)
    m = Pictura.app.mouse
    l,md,r = m.l && button != 1, m.m && button != 2, m.r && button != 3
    Pictura.app.mouse = (l=l, m=md, r=r, x=x, y=y, pos=Point(x, y), prev=m.prev)
    BUTTON = button # for now, TODO make a new type so we can compare BUTTON == "left", BUTTON == :l, etc.
    on_mouse_released[](BUTTON)
    nothing
end

function mouse_wheel_fn(vert::Float32, hori::Float32)
    WHEEL = Point(hori, vert) # TODO give option to invert scrollwheel?
    on_mouse_wheel[](WHEEL)
    nothing
end

function mouse_moved_fn(x_prev::Float32, y_prev::Float32, x::Float32, y::Float32)
    Pictura.app.mouse = Pictura.get_mouse_state()
    on_mouse_moved[]()
    nothing
end

function mouse_dragged_fn(x_prev::Float32, y_prev::Float32, x::Float32, y::Float32)
    # Pictura.app.mouse = Pictura.get_mouse_state()
    on_mouse_dragged[]()
    nothing
end

function key_pressed_fn(key::UInt8, shift::Int32, ctrl::Int32, alt::Int32)
    on_key_pressed[](key, Bool(shift), Bool(ctrl), Bool(alt))
    nothing
end

function key_released_fn(key::UInt8, shift::Int32, ctrl::Int32, alt::Int32)
    on_key_released[](key, Bool(shift), Bool(ctrl), Bool(alt))
    nothing
end

c_mouse_pressed_fn::Ptr{Nothing}  = 0
c_mouse_released_fn::Ptr{Nothing} = 0
c_mouse_wheel_fn::Ptr{Nothing}    = 0
c_mouse_moved_fn::Ptr{Nothing}    = 0
c_mouse_dragged_fn::Ptr{Nothing}  = 0
c_key_pressed_fn::Ptr{Nothing}    = 0
c_key_released_fn::Ptr{Nothing}   = 0




function set_default_callbacks()
    global on_mouse_pressed, on_mouse_released, on_mouse_wheel, on_mouse_moved, on_mouse_dragged, on_key_pressed, on_key_released
    on_mouse_pressed[] = (but) -> println("mouse pressed $x $y")
    on_mouse_released[] = (but) -> nothing
    on_mouse_wheel[] = (wheel) -> nothing
    on_mouse_moved[] = () -> nothing
    on_mouse_dragged[] = () -> nothing
    on_key_pressed[] = (k, s, c, a) -> println("key pressed $(Char(k))")
    on_key_released[] = (k, s, c, a) -> nothing

    Pictura.PicturaLib.set_mouse_pressed_fn(c_mouse_pressed_fn)
    Pictura.PicturaLib.set_mouse_released_fn(c_mouse_released_fn)
    Pictura.PicturaLib.set_mouse_wheel_fn(c_mouse_wheel_fn)
    Pictura.PicturaLib.set_mouse_moved_fn(c_mouse_moved_fn)
    Pictura.PicturaLib.set_mouse_dragged_fn(c_mouse_dragged_fn)
    Pictura.PicturaLib.set_key_pressed_fn(c_key_pressed_fn)
    Pictura.PicturaLib.set_key_released_fn(c_key_released_fn)
end



function __init__()
    global c_mouse_pressed_fn, c_mouse_released_fn, c_mouse_wheel_fn, c_mouse_moved_fn, c_mouse_dragged_fn, c_key_pressed_fn, c_key_released_fn

    c_mouse_pressed_fn = @cfunction(mouse_pressed_fn, Cvoid, (Float32, Float32, UInt32,))
    c_mouse_released_fn = @cfunction(mouse_released_fn, Cvoid, (Float32, Float32, UInt32,))
    c_mouse_wheel_fn = @cfunction(mouse_wheel_fn, Cvoid, (Float32, Float32))
    c_mouse_moved_fn = @cfunction(mouse_moved_fn, Cvoid, (Float32, Float32, Float32, Float32,))
    c_mouse_dragged_fn = @cfunction(mouse_dragged_fn, Cvoid, (Float32, Float32, Float32, Float32,))
    c_key_pressed_fn = @cfunction(key_pressed_fn, Cvoid, (UInt8, Int32, Int32, Int32,))
    c_key_released_fn = @cfunction(key_released_fn, Cvoid, (UInt8, Int32, Int32, Int32,))
end


macro mousepressed(expr)
    b = esc(:BUTTON)
    return quote
        $(@__MODULE__).on_mouse_pressed[] = ($b) -> begin
            $(esc(expr))
        end
    end
end

macro mousereleased(expr)
    b = esc(:BUTTON)
    return quote
        $(@__MODULE__).on_mouse_released[] = ($b) -> begin
            $(esc(expr))
        end
    end
end

macro mousewheel(expr)
    a = esc(:WHEEL)
    return quote
        $(@__MODULE__).on_mouse_wheel[] = ($a) -> begin
            $(esc(expr))
        end
    end
end

macro mousemoved(expr)
    return quote
        $(@__MODULE__).on_mouse_moved[] = () -> begin
            $(esc(expr))
        end
    end
end

macro mousedragged(expr)
    return quote
        $(@__MODULE__).on_mouse_dragged[] = () -> begin
            $(esc(expr))
        end
    end
end

macro keypressed(expr)
    a = esc(:KEYCODE)
    b = esc(:SHIFT)
    c = esc(:CTRL)
    d = esc(:ALT)
    return quote
        $(@__MODULE__).on_key_pressed[] = ($a, $b, $c, $d) -> begin
            $(esc(expr))
        end
    end
end

macro keyreleased(expr)
    a = esc(:KEYCODE)
    b = esc(:SHIFT)
    c = esc(:CTRL)
    d = esc(:ALT)
    return quote
        $(@__MODULE__).on_key_released[] = ($a, $b, $c, $d) -> begin
            $(esc(expr))
        end
    end
end


end # callbacks module


