module Pictura

export setup, color, @drawloop

using PShapes


struct Color
    color::UInt32
end

include("color.jl")



mutable struct Image
    w::UInt32
    h::UInt32
    ptr::Ptr{Cvoid}
    pixel_ptr::Union{Ptr{UInt32}, Nothing}
end

Image(w, h, ptr::Ptr{Cvoid}) = Image(w, h, ptr, nothing)






mutable struct App
    canvas::Image
    stroke::Color
    fill::Color
    framecount::UInt
    is_initialized::Bool
    is_looping::Bool
    mouse::@NamedTuple{l::Bool, m::Bool, r::Bool, pos::PShapes.Point{Float32}, prev::PShapes.Point{Float32}}
end

App() = App(
    Image(0,0,C_NULL), 
    color(0, 109, 156),
    color(12, 194, 235),
    0,
    false,
    true,
    (l=false, m=false, r=false, pos=Point{Float32}(0.0f0, 0.0f0), prev=Point{Float32}(0.0f0, 0.0f0))
)

app::App = App()


include("core.jl")



has_stroke() = alpha(app.stroke) > 0
has_fill()   = alpha(app.fill) > 0

stroke_color() = app.stroke
stroke_color(c::Color) = app.stroke = c
fillcolor() = app.fill
fillcolor(c::Color) = app.fill = c




function before_rendering()
    PicturaLib.wait_until_next_frame()
    PicturaLib.handle_events()

    app.canvas.w, app.canvas.h = get_window_size()
    new_ptr = get_canvas_ptr()
    if app.canvas.ptr != new_ptr
        app.canvas.ptr = new_ptr
        app.canvas.pixel_ptr = nothing
    end

    app.mouse = get_mouse_state()

    # set global canvas, global mouseX and stuff
end

function after_rendering()
    PicturaLib.present()
end

function render_present()
    after_rendering()
    before_rendering() 
end


Base.size(w::Integer, h::Integer) = (UInt32(w), UInt32(h))


noloop() = app.is_looping = false

function setup(size::Tuple{UInt32, UInt32}; borderless = false, fullscreen = false)
    w,h = size
    init(w, h)

    try 
        before_rendering()

        app.is_looping = true
    catch e
        quit()
        rethrow(e)
    end

end



macro drawloop(expr)
    return quote
        try 
            while app.is_looping
                before_rendering()

                if window_close_requested()
                    noloop()
                    continue
                end

                $expr

                after_rendering()
            end
            quit()
        catch e
            quit()
            rethrow(e)
        end
    end
end




end # module Pictura
