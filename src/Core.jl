
module Core

import ..Pictura
using ..Pictura: PicturaLib, Image, PicturaColor, color
using PicturaShapes

export App
export mouse, noloop, framerate, frametime, framecount
export render_present, @pictura, setup, @drawloop

#      __  __
#     |  \/  |___ _  _ ___ ___
#     | |\/| / _ \ || (_-</ -_)
#     |_|  |_\___/\_,_/__/\___|
#

struct MouseState
    l::Bool
    m::Bool
    r::Bool
    pos::Point{Float32}
    prev::Point{Float32}
end



function Base.getproperty(m::MouseState, s::Symbol)
    if s == :left
        return getfield(m, :l)
    elseif s == :middle
        return getfield(m, :m)
    elseif s == :right
        return getfield(m, :r)
    elseif s == :x
        return getfield(m, :pos).x
    elseif s == :y
        return getfield(m, :pos).y
    elseif s == :px
        return getfield(m, :prev).x
    elseif s == :py
        return getfield(m, :prev).y
    else
        return getfield(m, s)
    end
end

function Base.propertynames(p::MouseState, private::Bool=false)
    return (fieldnames(MouseState)..., :left, :middle, :right, :x, :y, :px, :py)
end

function MouseState()
    return MouseState(false, false, false, Point(0, 0), Point(0, 0))
end


let data = Vector{Int32}(undef, 7)

    global function get_mouse_state()

        PicturaLib.get_mouse_state(
            pointer(data, 1), # x
            pointer(data, 2), # y
            pointer(data, 3), # px
            pointer(data, 4), # py
            pointer(data, 5), # l
            pointer(data, 6), # m
            pointer(data, 7), # r
        )

        x, y = reinterpret(Float32, data[1]), reinterpret(Float32, data[2])
        px, py = reinterpret(Float32, data[3]), reinterpret(Float32, data[4])

        return MouseState(
            Bool(data[5]),
            Bool(data[6]),
            Bool(data[7]),
            Point(x, y),
            Point(px, py),
        )

    end
end

"""
    mouse()
Return the current state of the mouse.

The returned `MouseState` contains:
- `l`, `m`, `r`: Whether the left, middle, or right mouse buttons are pressed (`Bool`).
- `x`, `y`: The current mouse coordinates (`Float32`).
- `pos`: The current position as a `Point{Float32}`.
- `prev`: The previous position as a `Point{Float32}`.
"""
mouse() = Pictura.app.mouse





#        _
#       /_\  _ __ _ __
#      / _ \| '_ \ '_ \
#     /_/ \_\ .__/ .__/
#           |_|  |_|

mutable struct App
    canvas_id::Int
    canvas::Image
    stroke::PicturaColor
    strokewidth::Float64
    fill::PicturaColor
    framecount::UInt
    is_initialized::Bool
    is_looping::Bool
    mouse::MouseState
    frametime::Float64
    images::Vector{Image}
end

function App()
    return App(
        0,
        Image(0, 0, C_NULL),
        color(0, 109, 156),
        1.0,
        color(12, 194, 235),
        UInt(0),
        false,
        true,
        MouseState(),
        0.0,
        Image[]
    )
end


function init(w, h)
    if Pictura.app.is_initialized
        error("Pictura is already initialized")
    end
    Pictura.app = App()
    Pictura.app.is_initialized = true

    PicturaLib.init(UInt32(w), UInt32(h))

end


function get_canvas_ptr()
    return PicturaLib.get_canvas() # always returns the same address
end


window_close_requested() = PicturaLib.window_close_requested() |> Bool


"""
    noloop()
Stop the drawing loop after the current loop iteration.
"""
noloop() = Pictura.app.is_looping = false


function quit()
    if !Pictura.app.is_initialized
        error("Pictura is not initialized, so cannot quit ?! ...")
    end

    for img in Pictura.app.images
        PicturaLib.destroy_image(img.ptr)
    end

    PicturaLib.quit()
    Pictura.app = App()
    Pictura.app.is_initialized = false
    nothing
end

"""
    frametime()
Return the time in seconds of the last frame.
"""
frametime() = Pictura.app.frametime


"""
    framerate([f])
Return or set the target drawing framerate.

# Arguments
- `f`: The desired framerate. If no argument is provided, the current framerate is returned.
"""
framerate() = 1 / frametime()

function framerate(f)
    t = PicturaLib.set_framerate(Float64(f))
    if t != f
        @warn "framerate set to $t, and not $f"
    end
end


"""
    framecount()
Return the total number of frames rendered.
"""
framecount() = Pictura.app.framecount


is_key_pressed(key) = PicturaLib.is_key_pressed(UInt8(key)) |> Bool


let data = Vector{UInt32}(undef, 2)

    global function get_window_size()
        PicturaLib.get_window_size(pointer(data, 1), pointer(data, 2))
        return data[1], data[2]
    end

    global function get_display_size()
        PicturaLib.get_display_size(pointer(data, 1), pointer(data, 2))
        return data[1], data[2]
    end
end

let data = Vector{Int32}(undef, 2)

    global function get_window_position()
        PicturaLib.get_window_position(pointer(data, 1), pointer(data, 2))
        return data[1], data[2]
    end
end






#      ___                  _
#     |   \ _ _ __ ___ __ _| |___  ___ _ __
#     | |) | '_/ _` \ V  V / / _ \/ _ \ '_ \
#     |___/|_| \__,_|\_/\_/|_\___/\___/ .__/
#                                     |_|

function prepare_canvas(clear_transform)
    app = Pictura.app
    app.canvas.w, app.canvas.h = get_window_size()
    id = PicturaLib.get_canvas_id()
    if app.canvas_id != id
        app.canvas_id = id
        app.canvas.pixel_ptr = nothing
        app.canvas.pixel_array = nothing
    end

    app.framecount += 1

    app.frametime = PicturaLib.get_frametime()

    if clear_transform
        Pictura.Drawing.clear_transform()
    end
end

function before_rendering(clear_transform)
    PicturaLib.handle_events()
    prepare_canvas(clear_transform)
    Pictura.app.mouse = get_mouse_state()
end

function after_rendering()
    PicturaLib.present()
    PicturaLib.wait_until_next_frame()
end

"""
    render_present()
Manually present the currently rendered frame to the window
"""
function render_present(; clear_transform=true)
    after_rendering()
    before_rendering(clear_transform)
end


"""
    @pictura expr
Wrap a sketch in a safe execution environment.

When encountering an error, the application is shut down gracefully before rethrowing the error.

# Arguments
- `expr`: The sketch code to be executed.
"""
macro pictura(expr)
    return quote
        let
            try
                $(esc(expr))
            catch e
                if Pictura.app.is_initialized
                    quit()
                end
                rethrow(e)
            end
        end
    end
end

"""
    setup(width, height)
Initialize the application window and environment.

# Arguments
- `width, height`: Initial window size.
"""
function setup(w, h; borderless=false, fullscreen=false)
    setup(UInt32(w), UInt32(h), borderless=borderless, fullscreen=fullscreen)
end

function setup(w::UInt32, h::UInt32; borderless=false, fullscreen=false)
    init(w, h)
    Pictura.Callbacks.set_default_callbacks()
    Pictura.app.canvas.ptr = get_canvas_ptr()
    Pictura.app.is_looping = true
    before_rendering(true)
end


"""
    @drawloop expr
Start the main drawing loop.

This macro continuously executes the provided expr and renders each
frame until the window is closed or `noloop()` is called.

# Loop Structure:
1. handle events (see e.g. [@mousepressed](@ref), [@keypressed](@ref), ...)
2. expr
3. render present
4. wait/sleep

# Arguments
- `expr`: The code block to be executed every frame.
"""
macro drawloop(expr)
    return quote
        try

            while Pictura.app.is_looping

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







#      ___                  _
#     |   \ _ _ __ ___ __ _(_)_ _  __ _
#     | |) | '_/ _` \ V  V / | ' \/ _` |
#     |___/|_| \__,_|\_/\_/|_|_||_\__, |
#                                 |___/

function create_image(w, h)
    if Pictura.app.is_initialized
        img = Image(UInt32(w), UInt32(h), PicturaLib.create_image(UInt32(w), UInt32(h)))
        push!(Pictura.app.images, img)
        return img
    end
    error("Pictura is not initialized")
end


function create_image(pixels::Matrix{PicturaColor})
    if Pictura.app.is_initialized
        h, w = size(pixels)
        pixels_tr = transpose(pixels)[:, :]

        img_ptr = PicturaLib.create_image_from_pixels(w, h, pointer(pixels_tr, 1))
        if img_ptr == C_NULL
            error("failed to create image")
        end
        img = Image(UInt32(w), UInt32(h), img_ptr)
        push!(Pictura.app.images, img)
        return img

        # return pointer(pixels_tr, 1)
    end
end


function draw_background(img::Image, c::PicturaColor)
    f = NamedTuple(c, Float32)
    PicturaLib.draw_background(img.ptr, f.r, f.g, f.b, f.a)
end


function draw_point(img::Image, p::Point, c::PicturaColor, stroke_radius)
    f = NamedTuple(c, Float32)
    fp = Point{Float32}(p)
    PicturaLib.draw_point(img.ptr, fp.x, fp.y, f.r, f.g, f.b, f.a, Float32(stroke_radius))
end


function draw_segment(img::Image, s::Segment, c::PicturaColor, stroke_radius)
    f = NamedTuple(c, Float32)
    fs = Segment{Float32}(s)
    b = Rect{Float32}(bounding_box(fs, stroke_radius+1))
    crs = corners(b)
    PicturaLib.draw_line(
        img.ptr, fs.p1.x, fs.p1.y, fs.p2.x, fs.p2.y,
        f.r, f.g, f.b, f.a, Float32(stroke_radius),
        crs.tl.x, crs.tl.y, crs.tr.x, crs.tr.y, crs.bl.x, crs.bl.y, crs.br.x, crs.br.y
    )
end


function draw_ellipse(img::Image, e::Ellipse, fill::PicturaColor, stroke::PicturaColor, stroke_radius)
    ef = Ellipse{Float32}(e)
    fc = NamedTuple(fill, Float32)
    sc = NamedTuple(stroke, Float32)
    b = Rect{Float32}(bounding_box(e, stroke_radius+1))
    crs = corners(b)
    PicturaLib.draw_ellipse(
        img.ptr, ef.radius.x, ef.radius.y,
        fc.r, fc.g, fc.b, fc.a,
        sc.r, sc.g, sc.b, sc.a, Float32(stroke_radius),
        crs.tl.x, crs.tl.y, crs.tr.x, crs.tr.y, crs.bl.x, crs.bl.y, crs.br.x, crs.br.y
    )
end


function draw_rect(img::Image, r::Rect, corner_radius, fill::PicturaColor, stroke::PicturaColor, stroke_radius)
    fr = Rect{Float32}(r)
    fc = NamedTuple(fill, Float32)
    sc = NamedTuple(stroke, Float32)
    crs = bounding_box(r, stroke_radius+1) |> Rect{Float32} |> corners
    PicturaLib.draw_rect(
        img.ptr, fr.w, fr.h, Float32(abs(corner_radius)),
        fc.r, fc.g, fc.b, fc.a,
        sc.r, sc.g, sc.b, sc.a, Float32(stroke_radius),
        crs.tl.x, crs.tl.y, crs.tr.x, crs.tr.y, crs.bl.x, crs.bl.y, crs.br.x, crs.br.y
    )
end


function draw_image(dst::Image, src::Image; nearest_sampling=false, src_rect=nothing, dst_rect=nothing)
    if src_rect |> isnothing && dst_rect |> isnothing
        PicturaLib.draw_full_image(dst.ptr, src.ptr, Int32(nearest_sampling))
    else
        src_rect2 = Rect{Float32}(isnothing(src_rect) ? Rect(0, 0, src.w, src.h, 0.0) : src_rect)
        dst_rect2 = Rect{Float32}(isnothing(dst_rect) ? Rect(0, 0, dst.w, dst.h, 0.0) : dst_rect)

        sc = corners(src_rect2)
        dc = corners(dst_rect2)

        PicturaLib.draw_image(
            dst.ptr, src.ptr, Int32(nearest_sampling),
            dc.tl.x, dc.tl.y, dc.tr.x, dc.tr.y, dc.bl.x, dc.bl.y, dc.br.x, dc.br.y,
            sc.tl.x, sc.tl.y, sc.tr.x, sc.tr.y, sc.bl.x, sc.bl.y, sc.br.x, sc.br.y
        )
    end
end


function mix_channels(dst::Image, src::Image, red_row::NTuple{5,Float32}, grn_row::NTuple{5,Float32}, blu_row::NTuple{5,Float32}, alpha_row::NTuple{5,Float32})
    PicturaLib.mix_channels(
        dst.ptr, src.ptr,
        red_row[1], red_row[2], red_row[3], red_row[4],
        grn_row[1], grn_row[2], grn_row[3], grn_row[4],
        blu_row[1], blu_row[2], blu_row[3], blu_row[4],
        alpha_row[1], alpha_row[2], alpha_row[3], alpha_row[4],
        red_row[5], grn_row[5], blu_row[5], alpha_row[5],
    )
end


function mix_channels(dst::Image, src::Image, m, offset)
    mix_channels(
        dst, src,
        ntuple(i->i <= 4 ? Float32(m[1, i]) : Float32(offset[1]), Val(5)),
        ntuple(i->i <= 4 ? Float32(m[2, i]) : Float32(offset[2]), Val(5)),
        ntuple(i->i <= 4 ? Float32(m[3, i]) : Float32(offset[3]), Val(5)),
        ntuple(i->i <= 4 ? Float32(m[4, i]) : Float32(offset[4]), Val(5))
    )
end


function mix_channels(
    dst::Image, src::Image;
    red_out_red_in::Float32=0.0f0,
    red_out_green_in::Float32=0.0f0,
    red_out_blue_in::Float32=0.0f0,
    red_out_alpha_in::Float32=0.0f0,
    green_out_red_in::Float32=0.0f0,
    green_out_green_in::Float32=0.0f0,
    green_out_blue_in::Float32=0.0f0,
    green_out_alpha_in::Float32=0.0f0,
    blue_out_red_in::Float32=0.0f0,
    blue_out_green_in::Float32=0.0f0,
    blue_out_blue_in::Float32=0.0f0,
    blue_out_alpha_in::Float32=0.0f0,
    alpha_out_red_in::Float32=0.0f0,
    alpha_out_green_in::Float32=0.0f0,
    alpha_out_blue_in::Float32=0.0f0,
    alpha_out_alpha_in::Float32=0.0f0,
    red_offset::Float32=0.0f0,
    green_offset::Float32=0.0f0,
    blue_offset::Float32=0.0f0,
    alpha_offset::Float32=0.0f0,
)

    mix_channels(
        dst, src,
        (red_out_red_in, red_out_green_in, red_out_blue_in, red_out_alpha_in, red_offset),
        (green_out_red_in, green_out_green_in, green_out_blue_in, green_out_alpha_in, green_offset),
        (blue_out_red_in, blue_out_green_in, blue_out_blue_in, blue_out_alpha_in, blue_offset),
        (alpha_out_red_in, alpha_out_green_in, alpha_out_blue_in, alpha_out_alpha_in, alpha_offset)
    )
end


function mix_channels2(
    dst::Image, src::Image,
    red_row::NTuple{8,Float32}, grn_row::NTuple{8,Float32},
    blu_row::NTuple{8,Float32}, alpha_row::NTuple{7,Float32},
    seed::Float32)

    PicturaLib.mix_channels2(
        dst.ptr, src.ptr,
        red_row[1], red_row[2], red_row[3], red_row[4], red_row[5], red_row[6], red_row[7],
        grn_row[1], grn_row[2], grn_row[3], grn_row[4], grn_row[5], grn_row[6], grn_row[7],
        blu_row[1], blu_row[2], blu_row[3], blu_row[4], blu_row[5], blu_row[6], blu_row[7],
        alpha_row[1], alpha_row[2], alpha_row[3], alpha_row[4], alpha_row[5], alpha_row[6],
        red_row[8], grn_row[8], blu_row[8], alpha_row[7], seed
    )
end


function mix_channels2(dst::Image, src::Image, m, offset, seed)
    mix_channels2(
        dst, src,
        ntuple(i->i <= 7 ? Float32(m[1, i]) : Float32(offset[1]), Val(8)),
        ntuple(i->i <= 7 ? Float32(m[2, i]) : Float32(offset[2]), Val(8)),
        ntuple(i->i <= 7 ? Float32(m[3, i]) : Float32(offset[3]), Val(8)),
        ntuple(i->i <= 6 ? Float32(m[4, i]) : Float32(offset[4]), Val(7)),
        seed
    )
end


function mix_channels2(
    dst::Image, src::Image;
    red_out_red_in::Float32=0.0f0,
    red_out_green_in::Float32=0.0f0,
    red_out_blue_in::Float32=0.0f0,
    red_out_max_in::Float32=0.0f0,
    red_out_min_in::Float32=0.0f0,
    red_out_midtone_in::Float32=0.0f0,
    red_out_random_in::Float32=0.0f0,
    green_out_red_in::Float32=0.0f0,
    green_out_green_in::Float32=0.0f0,
    green_out_blue_in::Float32=0.0f0,
    green_out_max_in::Float32=0.0f0,
    green_out_min_in::Float32=0.0f0,
    green_out_midtone_in::Float32=0.0f0,
    green_out_random_in::Float32=0.0f0,
    blue_out_red_in::Float32=0.0f0,
    blue_out_green_in::Float32=0.0f0,
    blue_out_blue_in::Float32=0.0f0,
    blue_out_max_in::Float32=0.0f0,
    blue_out_min_in::Float32=0.0f0,
    blue_out_midtone_in::Float32=0.0f0,
    blue_out_random_in::Float32=0.0f0,
    alpha_out_red_in::Float32=0.0f0,
    alpha_out_green_in::Float32=0.0f0,
    alpha_out_blue_in::Float32=0.0f0,
    alpha_out_max_in::Float32=0.0f0,
    alpha_out_min_in::Float32=0.0f0,
    alpha_out_midtone_in::Float32=0.0f0,
    red_offset::Float32=0.0f0,
    green_offset::Float32=0.0f0,
    blue_offset::Float32=0.0f0,
    alpha_offset::Float32=0.0f0,
)

    mix_channels2(
        dst, src,
        (red_out_red_in, red_out_green_in, red_out_blue_in, red_out_max_in, red_out_min_in, red_out_midtone_in, red_out_random_in, red_offset),
        (green_out_red_in, green_out_green_in, green_out_blue_in, green_out_max_in, green_out_min_in, green_out_midtone_in, green_out_random_in, green_offset),
        (blue_out_red_in, blue_out_green_in, blue_out_blue_in, blue_out_max_in, blue_out_min_in, blue_out_midtone_in, blue_out_random_in, blue_offset),
        (alpha_out_red_in, alpha_out_green_in, alpha_out_blue_in, alpha_out_max_in, alpha_out_min_in, alpha_out_midtone_in, alpha_offset),
        seed
    )
end


function filter(dst::Image, src::Image, weights::NTuple{9,Float32}, wmax::Float32, wmin::Float32, wavg::Float32, wstd::Float32, off::Float32)
    PicturaLib.filter(
        dst.ptr, src.ptr,
        weights[1], weights[2], weights[3], weights[4], weights[5], weights[6], weights[7], weights[8], weights[9],
        wmax, wmin, wavg, wstd, off
    )
end

function filter(dst::Image, src::Image, w, wmax, wmin, wavg, wstd, offset)
    weights = Float32.((w[1, 1], w[1, 2], w[1, 3], w[2, 1], w[2, 2], w[2, 3], w[3, 1], w[3, 2], w[3, 3]))
    filter(dst, src, weights, Float32(wmax), Float32(wmin), Float32(wavg), Float32(wstd), Float32(offset))
end


end
