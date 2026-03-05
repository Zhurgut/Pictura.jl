module Pictura

export setup, color, @drawloop
export strokecolor, fillcolor, mouse, noloop, framerate, framecount
export loadpixels, updatepixels, pixels, width, height

export @mousepressed , @mousereleased, @mousemoved, @mousedragged, @mousewheel, @keypressed, @keyreleased
export CENTER, MIDDLE, WHEEL, MOUSEWHEEL, ENTER, BACK, BACKSPACE, TAB, SPACE, SPACEBAR, COMMA, PERIOD

include("picturalib.jl")
using .PicturaLib

export DELETE, RIGHT, LEFT, DOWN, UP, SHIFT, CTRL, ALT, HOME, END, PAGEUP, PAGEDOWN, INSERT

Base.map(x::Real, a::Real, b::Real, A::Real, B::Real) = fma(x, B-A, fma(A, b, -B*a)) * (1 / (b-a))


using PicturaShapes


struct Color
    color::UInt32
end

include("color.jl")



mutable struct Image
    w::UInt32
    h::UInt32
    ptr::Ptr{Cvoid}
    pixel_ptr::Union{Ptr{UInt32}, Nothing}
    pixel_array::Union{Matrix{Color}, Nothing}
end

Image(w, h, ptr::Ptr{Cvoid}) = Image(w, h, ptr, nothing, nothing)

include("image.jl")




mutable struct App
    canvas_id::Int
    canvas::Image
    stroke::Color
    fill::Color
    framecount::UInt
    is_initialized::Bool
    is_looping::Bool
    mouse::@NamedTuple{l::Bool, m::Bool, r::Bool, x::Float32, y::Float32, pos::Point{Float32}, prev::Point{Float32}}
    frametimes::NTuple{5, Float64}
    images::Vector{Image}
end

App() = App(
    0,
    Image(0,0, C_NULL), 
    color(0, 109, 156),
    color(12, 194, 235),
    0,
    false,
    true,
    (l=false, m=false, r=false, x=0.0f0, y=0.0f0, pos=Point{Float32}(0.0f0, 0.0f0), prev=Point{Float32}(0.0f0, 0.0f0)),
    (0.0, 0.0, 0.0, 0.0, 0.0),
    Image[]
)

app::App = App()

include("callbacks.jl")
using .Callbacks


include("core.jl")


has_stroke() = alpha(app.stroke) > 0
has_fill()   = alpha(app.fill) > 0

strokecolor() = app.stroke
strokecolor(c::Color) = app.stroke = c
strokecolor(x) = strokecolor(color(x))
strokecolor(r, g, b) = strokecolor(color(r, g, b))
strokecolor(r, g, b, a) = strokecolor(color(r, g, b, a))

fillcolor() = app.fill
fillcolor(c::Color) = app.fill = c
fillcolor(x) = fillcolor(color(x))
fillcolor(r, g, b) = fillcolor(color(r, g, b))
fillcolor(r, g, b, a) = fillcolor(color(r, g, b, a))

width() = width(app.canvas)
height() = height(app.canvas)

loadpixels() = loadpixels(app.canvas)
updatepixels() = updatepixels(app.canvas)
pixels() = pixels(app.canvas)

noloop() = app.is_looping = false

mouse() = app.mouse

framerate() = length(app.frametimes) / sum(app.frametimes)
framecount() = app.framecount





function before_rendering()
    PicturaLib.wait_until_next_frame()
    PicturaLib.handle_events()

    app.canvas.w, app.canvas.h = get_window_size()
    id = PicturaLib.get_canvas_id()
    if app.canvas_id != id
        app.canvas_id = id
        app.canvas.pixel_ptr = nothing
        app.canvas.pixel_array = nothing
    end

    app.mouse = get_mouse_state()

    app.framecount += 1

    app.frametimes = (PicturaLib.get_frametime(), app.frametimes[1:end-1]...)
end

function after_rendering()
    PicturaLib.present()
end

public render_present
function render_present()
    after_rendering()
    before_rendering() 
end


Base.size(w::Integer, h::Integer) = (UInt32(w), UInt32(h))




function setup(size::Tuple{UInt32, UInt32}; borderless = false, fullscreen = false)
    w,h = size
    init(w, h)
    Callbacks.set_default_callbacks()
    app.canvas.ptr = get_canvas_ptr()
    app.is_looping = true
end



macro drawloop(expr)
    return quote
        try 
            before_rendering()

            while app.is_looping

                if window_close_requested()
                    noloop()
                    continue
                end

                $(esc(expr))

                render_present()
            end
            quit()
        catch e
            quit()
            rethrow(e)
        end
    end
end




end # module Pictura






