
module Callbacks

import ..Pictura
using PicturaShapes

export @mousepressed ,@mousereleased, @mousemoved, @mousedragged, @mousewheel, @keypressed, @keyreleased


struct MouseButton
    value::UInt8
end

struct Key
    value::UInt8
end

# mouse wheel button
const CENTER = 2
const MIDDLE = CENTER
const WHEEL = CENTER
const MOUSEWHEEL = CENTER
# extra keyboard keys
# for the others, use '+', '-', '/', ... (if these keys work for you)
const ENTER = Int('\r')
const BACK = Key(UInt8('\b'))
const BACKSPACE = BACK
const TAB = Key(UInt8('\t'))
const SPACE = Int(' ')
const SPACEBAR = SPACE
const COMMA = Int(',')
const PERIOD = Int('.')

export CENTER, MIDDLE, WHEEL, MOUSEWHEEL, ENTER, BACK, BACKSPACE, TAB, SPACE, SPACEBAR, COMMA, PERIOD

Base.:(==)(b, m::MouseButton) = m == b
function Base.:(==)(m::MouseButton, b::Int)
    if b == Pictura.PicturaLib.LEFT
        return m.value == 1
    elseif b == CENTER
        return m.value == 2
    elseif b == Pictura.PicturaLib.RIGHT
        return m.value == 3
    end
    false
end
function Base.:(==)(m::MouseButton, b::Symbol)
    if b == :left || b == :l
        return m.value == 1
    elseif b == :middle || b == :m || b == :center || b == :wheel || b == :mousewheel
        return m.value == 2
    elseif b == :right || b == :r
        return m.value == 3
    end
    false
end
Base.:(==)(m::MouseButton, b::String) = m == Symbol(b)
Base.:(==)(m::MouseButton, b::Char) = m == Symbol(b)

Base.:(==)(b::Key, k::Key) = k.value == b.value
Base.:(==)(b, k::Key) = k == b
Base.:(==)(k::Key, b::Char) = k.value == UInt8(b)
function Base.:(==)(k::Key, b::Int)
    if b < 10
        return k.value == b + Int('0')
    end
    return k.value == b
end
function Base.:(==)(k::Key, b::Symbol)
    if b == :enter
        return k == ENTER
    elseif b == :back || b == :backspace
        return k == BACK
    elseif b == :tab
        return k == TAB
    elseif b == :space || b == :spacebar
        return k == SPACE
    elseif b == :comma
        return k == COMMA
    elseif b == :period
        return k == PERIOD
    end
    false
end
Base.:(==)(k::Key, b::String) = if length(b) == 1
        return k == Char(b[1])
    else
        return k == Symbol(b)
end


const on_mouse_pressed::Ref{Function} = Ref{Function}((BUTTON) -> nothing)
const on_mouse_released::Ref{Function} = Ref{Function}((BUTTON) -> nothing)
const on_mouse_wheel::Ref{Function} = Ref{Function}((WHEEL) -> nothing)
const on_mouse_moved::Ref{Function} = Ref{Function}(() -> nothing)
const on_mouse_dragged::Ref{Function} = Ref{Function}(() -> nothing)
const on_key_pressed::Ref{Function} = Ref{Function}((k, s, c, a) -> nothing)
const on_key_released::Ref{Function} = Ref{Function}((k, s, c, a) -> nothing)

function mouse_pressed_fn(x::Float32, y::Float32, button::UInt32)
    m = Pictura.app.mouse
    l,md,r = m.l || button == 1, m.m || button == 2, m.r || button == 3
    Pictura.app.mouse = (l=l, m=md, r=r, x=x, y=y, pos=Point(x, y), prev=m.prev)
    BUTTON = MouseButton(UInt8(button))
    on_mouse_pressed[](BUTTON)
    nothing
end

function mouse_released_fn(x::Float32, y::Float32, button::UInt32)
    m = Pictura.app.mouse
    l,md,r = m.l && button != 1, m.m && button != 2, m.r && button != 3
    Pictura.app.mouse = (l=l, m=md, r=r, x=x, y=y, pos=Point(x, y), prev=m.prev)
    BUTTON = MouseButton(UInt8(button))
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
    on_key_pressed[](Key(key), Bool(shift), Bool(ctrl), Bool(alt))
    nothing
end

function key_released_fn(key::UInt8, shift::Int32, ctrl::Int32, alt::Int32)
    on_key_released[](Key(key), Bool(shift), Bool(ctrl), Bool(alt))
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
    on_mouse_pressed[] = (but) -> nothing
    on_mouse_released[] = (but) -> nothing
    on_mouse_wheel[] = (wheel) -> nothing
    on_mouse_moved[] = () -> nothing
    on_mouse_dragged[] = () -> nothing
    on_key_pressed[] = (k, s, c, a) -> nothing
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
    a = esc(:KEY)
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
    a = esc(:KEY)
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


