
include("picturalib.jl")

function init(w, h)
    global app
    if app.is_initialized
        error("Pictura is already initialized")
    end

    PicturaLib.init(UInt32(w), UInt32(h))
    set_default_callbacks()

    app = App()
    app.is_initialized = true

end

function quit()
    global app
    if !app.is_initialized
        error("Pictura is not initialized, so cannot quit ?! ...")
    end

    PicturaLib.quit()
    app = App()
    app.is_initialized = false
end

function framerate(f)
    t = PicturaLib.set_framerate(Float64(f))
    if t != f
        @warn "framerate set to $t, and not $f"
    end
end

function get_canvas_ptr()
    return PicturaLib.get_canvas() # always returns the same address
end

function draw_background(img::Image, c::Color)
    f = floats(c, Float32)
    PicturaLib.draw_background(img.ptr, f.r, f.g, f.b, f.a)
end

window_close_requested() = PicturaLib.window_close_requested() |> Bool


function create_image(w, h)
    img = Image(UInt32(w), UInt32(h), PicturaLib.create_image(UInt32(w), UInt32(h)))
    finalizer(img) do x
        PicturaLib.destroy_image(x.ptr)
    end
end

function create_image(pixels::Matrix{Color})
    h, w = size(pixels)
    pixels_tr = transpose(pixels)[:, :]
    img_ptr = PicturaLib.create_image_from_pixels(w, h, pointer(pixels_tr, 1))
    if img_ptr == C_NULL
        error("failed to create image")
    end
    img = Image(UInt32(w), UInt32(h), img_ptr)

    finalizer(img) do x
        PicturaLib.destroy_image(x.ptr)
    end
end

function load_pixels(img::Image)
    pixels = PicturaLib.load_pixels(img.ptr)
    if pixels == C_NULL
        error("failed to load pixels")
    end
    img.pixel_ptr = pixels
end

update_pixels(img::Image) = PicturaLib.update_pixels(img.ptr)

function draw_point(img::Image, p::Point, c::Color, stroke_radius)
    f = floats(c, Float32)
    fp = Point{Float32}(p)
    PicturaLib.draw_point(img.ptr, fp.x, fp.y, f.r, f.g, f.b, f.a, Float32(stroke_radius))
end

function draw_segment(img::Image, s::Segment, c::Color, stroke_radius)
    f = floats(c, Float32)
    fs = Segment{Float32}(s)
    b = Rect{Float32}(bounding_box(fs, stroke_radius+1))
    crs = corners(b)
    PicturaLib.draw_line(
        img.ptr, fs.p1.x, fs.p1.y, fs.p2.x, fs.p2.y, 
        f.r, f.g, f.b, f.a, Float32(stroke_radius), 
        crs.tl.x, crs.tl.y, crs.tr.x, crs.tr.y, crs.bl.x, crs.bl.y, crs.br.x, crs.br.y
    )
end

function draw_ellipse(img::Image, e::Ellipse, fill::Color, stroke::Color, stroke_radius)
    ef = Ellipse{Float32}(e)
    fc = floats(fill, Float32)
    sc = floats(stroke, Float32)
    b = Rect{Float32}(bounding_box(e, stroke_radius+1))
    crs = corners(b)
    PicturaLib.draw_ellipse(
        img.ptr, ef.radius.x, ef.radius.y,
        fc.r, fc.g, fc.b, fc.a,
        sc.r, sc.g, sc.b, sc.a, Float32(stroke_radius),
        crs.tl.x, crs.tl.y, crs.tr.x, crs.tr.y, crs.bl.x, crs.bl.y, crs.br.x, crs.br.y
    )
end

function draw_rect(img::Image, r::Rect, corner_radius, fill::Color, stroke::Color, stroke_radius)
    fr = Rect{Float32}(r)
    fc = floats(fill, Float32)
    sc = floats(stroke, Float32)
    crs = bounding_box(r, stroke_radius+1) |> Rect{Float32} |> corners
    PicturaLib.draw_rect(
        img.ptr, fr.w, fr.h, Float32(corner_radius),
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

        return (
            l = Bool(data[5]),
            m = Bool(data[6]),
            r = Bool(data[7]),
            x = reinterpret(Float32, data[1]),
            y = reinterpret(Float32, data[2]),
            pos = Point(reinterpret(Float32, data[1]), reinterpret(Float32, data[2])),
            prev = Point(reinterpret(Float32, data[3]), reinterpret(Float32, data[4])),
        )

    end

    global function get_window_position()
        PicturaLib.get_window_position(pointer(data, 1), pointer(data, 2))
        return data[1], data[2]
    end
end

is_key_pressed(key) = PicturaLib.is_key_pressed(UInt8(key)) |> Bool



function mouse_pressed_fn(x::Float32, y::Float32, button::UInt32)
    @invokelatest on_mouse_pressed(x, y, button)
    Cvoid
end
c_mouse_pressed_fn = @cfunction(mouse_pressed_fn, Cvoid, (Float32, Float32, UInt32,))


function mouse_released_fn(x::Float32, y::Float32, button::UInt32)
    @invokelatest on_mouse_released(x, y, button)
    Cvoid
end
c_mouse_released_fn = @cfunction(mouse_released_fn, Cvoid, (Float32, Float32, UInt32,))


function mouse_wheel_fn(vert::Float32, hori::Float32)
    @invokelatest on_mouse_wheel(vert, hori)
    Cvoid
end
c_mouse_wheel_fn = @cfunction(mouse_wheel_fn, Cvoid, (Float32, Float32))


function mouse_moved_fn(x_prev::Float32, y_prev::Float32, x::Float32, y::Float32)
    @invokelatest on_mouse_moved(x_prev, y_prev, x, y)
    Cvoid
end
c_mouse_moved_fn = @cfunction(mouse_moved_fn, Cvoid, (Float32, Float32, Float32, Float32,))


function mouse_dragged_fn(x_prev::Float32, y_prev::Float32, x::Float32, y::Float32)
    @invokelatest on_mouse_dragged(x_prev, y_prev, x, y)
    Cvoid
end
c_mouse_dragged_fn = @cfunction(mouse_dragged_fn, Cvoid, (Float32, Float32, Float32, Float32,))


function key_pressed_fn(key::UInt8, shift::Int32, ctrl::Int32, alt::Int32)
    @invokelatest on_key_pressed(key, Bool(shift), Bool(ctrl), Bool(alt))
    Cvoid
end
c_key_pressed_fn = @cfunction(key_pressed_fn, Cvoid, (UInt8, Int32, Int32, Int32,))


function key_released_fn(key::UInt8, shift::Int32, ctrl::Int32, alt::Int32)
    @invokelatest on_key_released(key, Bool(shift), Bool(ctrl), Bool(alt))
    Cvoid
end
c_key_released_fn = @cfunction(key_released_fn, Cvoid, (UInt8, Int32, Int32, Int32,))

function set_default_callbacks()
    eval(quote
        on_mouse_pressed(x, y, b) = nothing
        on_mouse_released(x, y, b) = nothing
        on_mouse_wheel(v, h) = nothing
        on_mouse_moved(px, py, x, y) = nothing
        on_mouse_dragged(px, py, x, y) = nothing
        on_key_pressed(k, s, c, a) = nothing
        on_key_released(k, s, c, a) = nothing
    end)

    PicturaLib.set_mouse_pressed_fn(c_mouse_pressed_fn)
    PicturaLib.set_mouse_released_fn(c_mouse_released_fn)
    PicturaLib.set_mouse_wheel_fn(c_mouse_wheel_fn)
    PicturaLib.set_mouse_moved_fn(c_mouse_moved_fn)
    PicturaLib.set_mouse_dragged_fn(c_mouse_dragged_fn)
    PicturaLib.set_key_pressed_fn(c_key_pressed_fn)
    PicturaLib.set_key_released_fn(c_key_released_fn)
end
