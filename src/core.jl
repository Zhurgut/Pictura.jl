
function init(w, h)
    global app
    if app.is_initialized
        error("Pictura is already initialized")
    end
    app = App()
    app.is_initialized = true

    PicturaLib.init(UInt32(w), UInt32(h))
    
end

function quit()
    global app
    if !app.is_initialized
        error("Pictura is not initialized, so cannot quit ?! ...")
    end

    for img in app.images
        PicturaLib.destroy_image(img.ptr)
    end

    PicturaLib.quit()
    app = App()
    app.is_initialized = false
    nothing
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
    if app.is_initialized
        img = Image(UInt32(w), UInt32(h), PicturaLib.create_image(UInt32(w), UInt32(h)))
        push!(app.images, img)
        return img
    end
    error("Pictura is not initialized")
end

function create_image(pixels::Matrix{Color})
    if app.is_initialized
        h, w = size(pixels)
        pixels_tr = transpose(pixels)[:, :]
        img_ptr = PicturaLib.create_image_from_pixels(w, h, pointer(pixels_tr, 1))
        if img_ptr == C_NULL
            error("failed to create image")
        end
        img = Image(UInt32(w), UInt32(h), img_ptr)
        push!(app.images, img)
        return img
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

