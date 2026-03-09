module Pictura

export setup, color, @drawloop, @pictura
export mouse, noloop, framerate, framecount
export loadpixels, updatepixels, pixels, width, height

export @mousepressed , @mousereleased, @mousemoved, @mousedragged, @mousewheel, @keypressed, @keyreleased
export CENTER, MIDDLE, WHEEL, MOUSEWHEEL, ENTER, BACK, BACKSPACE, TAB, SPACE, SPACEBAR, COMMA, PERIOD

include("PicturaLib.jl")
using .PicturaLib

export DELETE, RIGHT, LEFT, DOWN, UP, SHIFT, CTRL, ALT, HOME, END, PAGEUP, PAGEDOWN, INSERT

Base.map(x::Real, a::Real, b::Real, A::Real, B::Real) = fma(x, B-A, fma(A, b, -B*a)) * (1 / (b-a))


using PicturaShapes




include("PicturaColors.jl")
using .PicturaColors
export color, red, green, blue



mutable struct Image
    w::UInt32
    h::UInt32
    ptr::Ptr{Cvoid}
    pixel_ptr::Union{Ptr{UInt32}, Nothing}
    pixel_array::Union{Matrix{PicturaColor}, Nothing}
end

Image(w, h, ptr::Ptr{Cvoid}) = Image(w, h, ptr, nothing, nothing)

include("image.jl")




mutable struct App
    canvas_id::Int
    canvas::Image
    stroke::PicturaColor
    strokewidth::Float64
    fill::PicturaColor
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
    1.0,
    color(12, 194, 235),
    0,
    false,
    true,
    (l=false, m=false, r=false, x=0.0f0, y=0.0f0, pos=Point{Float32}(0.0f0, 0.0f0), prev=Point{Float32}(0.0f0, 0.0f0)),
    (0.0, 0.0, 0.0, 0.0, 0.0),
    Image[]
)

app::App = App()

include("Callbacks.jl")
using .Callbacks


include("core.jl")

export strokecolor, fillcolor, strokewidth, nostroke, nofill

has_stroke() = alpha(app.stroke) > 0
has_fill()   = alpha(app.fill) > 0

strokecolor() = app.stroke
strokecolor(c::PicturaColor) = app.stroke = c
strokecolor(x) = strokecolor(color(x))
strokecolor(r, g, b) = strokecolor(color(r, g, b))
strokecolor(r, g, b, a) = strokecolor(color(r, g, b, a))

strokewidth(w) = app.strokewidth=abs(w)
strokewidth() = app.strokewidth

fillcolor() = app.fill
fillcolor(c::PicturaColor) = app.fill = c
fillcolor(x) = fillcolor(color(x))
fillcolor(r, g, b) = fillcolor(color(r, g, b))
fillcolor(r, g, b, a) = fillcolor(color(r, g, b, a))

nostroke() = strokecolor(0,0,0,0)
nofill() = fillcolor(0,0,0,0)

width() = width(app.canvas)
height() = height(app.canvas)

loadpixels() = loadpixels(app.canvas)
updatepixels() = updatepixels(app.canvas)
pixels() = pixels(app.canvas)

noloop() = app.is_looping = false

mouse() = app.mouse

framerate() = length(app.frametimes) / sum(app.frametimes)
framecount() = app.framecount


export background
function background(img::Image, c::PicturaColor)
    f = floats(c, Float32)
    PicturaLib.draw_background(img.ptr, f.r, f.g, f.b, 1.0)
end
background(img::Image, x) = background(img, color(x))
background(img::Image, r, g, b) = background(img, color(r, g, b))
background(x) = background(app.canvas, x)
background(r, g, b) = backgroudn(app.canvas, r, g, b)



include("Drawing.jl")
export draw, transform
export translate, scale, rotate
PicturaShapes.translate(dx, dy) = Drawing.tf_translate(dx, dy)
PicturaShapes.scale(s) = Drawing.tf_scale(s, s)
PicturaShapes.scale(sx, sy) = Drawing.tf_scale(sx, sy)
PicturaShapes.rotate(a) = Drawing.tf_rotate(a)



export point, segment, line, rect, circle, ellipse

point(img, x, y) = Drawing.draw(img, Point(x, y))
point(x, y) = point(app.canvas, x, y)

segment(img, x1, y1, x2, y2) = Drawing.draw(img, Segment(x1, y1, x2, y2))
segment(x1, y1, x2, y2) = segment(app.canvas, x1, y1, x2, y2)

line(img, x1, y1, x2, y2; infinite=false) = infinite ? Drawing.draw(img, Line(x1, y1, x2, y2)) : segment(img, x1, y1, x2, y2)
line(x1, y1, x2, y2; infinite=false) = line(app.canvas, x1, y1, x2, y2, infinite=infinite)

function rect(img::Image, x, y, w, h, corner_radius=0; angle=0, mode=:corner)
    if angle == 0
        Drawing.draw(img, AxisRect(x, y, w, h, mode=mode), corner_radius)
    else
        Drawing.draw(img, Rect(x, y, w, h, angle, mode=mode), corner_radius)
    end
end
rect(x, y, w, h, corner_radius=0; angle=0, mode=:corner) = rect(app.canvas, x, y, w, h, corner_radius, angle=angle, mode=mode)

circle(img, x, y, r) = Drawing.draw(img, Circle(x, y, r))
circle(x, y, r) = circle(app.canvas, x, y, r)

ellipse(img::Image, x, y, rx, ry, angle=0) = Drawing.draw(img, Ellipse(x, y, rx, ry, angle))
ellipse(x, y, rx, ry, angle=0) = ellipse(app.canvas, x, y, rx, ry, angle)



import FileIO

export load_image, save_image, save_frame

function load_image(path)
    @assert app.is_initialized
    
    img::Matrix{PicturaColor} = FileIO.load(path)
    return create_image(img)
end

function save_image(img::Image, path)
    @assert app.is_initialized
    
    out::Matrix{PicturaColors.Colors.RGBA{Float32}} = pixels(img)[:, :]
    FileIO.save(path, out)
end

function save_frame(path)
    @assert app.is_initialized
    save_image(app.canvas, path)
end




function before_rendering(clear_transform)
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

    if clear_transform
        Drawing.clear_transform()
    end
end

function after_rendering()
    PicturaLib.present()
    
end


function render_present(;clear_transform=true)
    after_rendering()
    before_rendering(clear_transform) 
end


Base.size(w::Integer, h::Integer) = (UInt32(w), UInt32(h))


macro pictura(expr)
    return quote
        let
            try 
                $(esc(expr))
            catch e
                if $(@__MODULE__).app.is_initialized
                    quit()
                end
                rethrow(e)
            end
        end
    end
end


function setup(size::Tuple{UInt32, UInt32}; borderless = false, fullscreen = false)
    w,h = size
    init(w, h)
    Callbacks.set_default_callbacks()
    app.canvas.ptr = get_canvas_ptr()
    app.is_looping = true
    before_rendering(true)
end



macro drawloop(expr)
    return quote
        try 

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






