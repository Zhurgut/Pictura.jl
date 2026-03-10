
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

function draw_background(img::Image, c::PicturaColor)
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

function create_image(pixels::Matrix{PicturaColor})
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

        # return pointer(pixels_tr, 1)
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

function draw_point(img::Image, p::Point, c::PicturaColor, stroke_radius)
    f = floats(c, Float32)
    fp = Point{Float32}(p)
    PicturaLib.draw_point(img.ptr, fp.x, fp.y, f.r, f.g, f.b, f.a, Float32(stroke_radius))
end

function draw_segment(img::Image, s::Segment, c::PicturaColor, stroke_radius)
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

function draw_ellipse(img::Image, e::Ellipse, fill::PicturaColor, stroke::PicturaColor, stroke_radius)
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

function draw_rect(img::Image, r::Rect, corner_radius, fill::PicturaColor, stroke::PicturaColor, stroke_radius)
    fr = Rect{Float32}(r)
    fc = floats(fill, Float32)
    sc = floats(stroke, Float32)
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

function mix_channels(dst::Image, src::Image, red_row::NTuple{5, Float32}, grn_row::NTuple{5, Float32}, blu_row::NTuple{5, Float32}, alpha_row::NTuple{5, Float32})
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
        red_out_red_in::Float32   = 0.0f0,
        red_out_green_in::Float32 = 0.0f0,
        red_out_blue_in::Float32  = 0.0f0,
        red_out_alpha_in::Float32 = 0.0f0,
        green_out_red_in::Float32   = 0.0f0,
        green_out_green_in::Float32 = 0.0f0,
        green_out_blue_in::Float32  = 0.0f0,
        green_out_alpha_in::Float32 = 0.0f0,
        blue_out_red_in::Float32   = 0.0f0,
        blue_out_green_in::Float32 = 0.0f0,
        blue_out_blue_in::Float32  = 0.0f0,
        blue_out_alpha_in::Float32 = 0.0f0,
        alpha_out_red_in::Float32   = 0.0f0,
        alpha_out_green_in::Float32 = 0.0f0,
        alpha_out_blue_in::Float32  = 0.0f0,
        alpha_out_alpha_in::Float32 = 0.0f0,
        red_offset::Float32   = 0.0f0,
        green_offset::Float32 = 0.0f0,
        blue_offset::Float32  = 0.0f0,
        alpha_offset::Float32 = 0.0f0,
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
        red_row::NTuple{8, Float32}, grn_row::NTuple{8, Float32}, 
        blu_row::NTuple{8, Float32}, alpha_row::NTuple{7, Float32}, 
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
        red_out_red_in::Float32   = 0.0f0,
        red_out_green_in::Float32 = 0.0f0,
        red_out_blue_in::Float32  = 0.0f0,
        red_out_max_in::Float32   = 0.0f0,
        red_out_min_in::Float32   = 0.0f0,
        red_out_midtone_in::Float32 = 0.0f0,
        red_out_random_in::Float32  = 0.0f0,
        green_out_red_in::Float32   = 0.0f0,
        green_out_green_in::Float32 = 0.0f0,
        green_out_blue_in::Float32  = 0.0f0,
        green_out_max_in::Float32   = 0.0f0,
        green_out_min_in::Float32   = 0.0f0,
        green_out_midtone_in::Float32 = 0.0f0,
        green_out_random_in::Float32  = 0.0f0,
        blue_out_red_in::Float32   = 0.0f0,
        blue_out_green_in::Float32 = 0.0f0,
        blue_out_blue_in::Float32  = 0.0f0,
        blue_out_max_in::Float32   = 0.0f0,
        blue_out_min_in::Float32   = 0.0f0,
        blue_out_midtone_in::Float32 = 0.0f0,
        blue_out_random_in::Float32  = 0.0f0,
        alpha_out_red_in::Float32   = 0.0f0,
        alpha_out_green_in::Float32 = 0.0f0,
        alpha_out_blue_in::Float32  = 0.0f0,
        alpha_out_max_in::Float32   = 0.0f0,
        alpha_out_min_in::Float32   = 0.0f0,
        alpha_out_midtone_in::Float32 = 0.0f0,
        red_offset::Float32   = 0.0f0,
        green_offset::Float32 = 0.0f0,
        blue_offset::Float32  = 0.0f0,
        alpha_offset::Float32 = 0.0f0,
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

function filter(dst::Image, src::Image, weights::NTuple{9, Float32}, wmax::Float32, wmin::Float32, wavg::Float32, wstd::Float32, off::Float32)
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

