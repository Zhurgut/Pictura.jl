module Drawing


import ..Pictura
using ..Pictura: Core, PicturaColor, Image, color
using PicturaShapes

export strokecolor, strokewidth, nostroke, fillcolor, nofill
export transform, translate, scale, rotate
export draw, background, point, segment, line, rect, circle, ellipse, image




#       ___     _            
#      / __|___| |___ _ _ ___
#     | (__/ _ \ / _ \ '_(_-<
#      \___\___/_\___/_| /__/
#                            

has_stroke() = alpha(Pictura.app.stroke) > 0
has_fill() = alpha(Pictura.app.fill) > 0

"""
    strokecolor([c])
Return or set the current stroke color.

# Arguments
- `c`: The color to set. If no argument is provided, the current stroke color is returned.
"""
strokecolor() = Pictura.app.stroke
strokecolor(c::PicturaColor) = Pictura.app.stroke = c
strokecolor(x) = strokecolor(color(x))
strokecolor(r, g, b) = strokecolor(color(r, g, b))
strokecolor(r, g, b, a) = strokecolor(color(r, g, b, a))

"""
    strokewidth([w])
Return or set the current stroke width.

# Arguments
- `w`: The width to set. If no argument is provided, the current stroke width is returned.
"""
strokewidth(w) = Pictura.app.strokewidth=abs(w)
strokewidth() = Pictura.app.strokewidth


"""
    fillcolor([c])
Return or set the current fill color.

# Arguments
- `c`: The color to set. If no argument is provided, the current fill color is returned.
"""
fillcolor() = Pictura.app.fill
fillcolor(c::PicturaColor) = Pictura.app.fill = c
fillcolor(x) = fillcolor(color(x))
fillcolor(r, g, b) = fillcolor(color(r, g, b))
fillcolor(r, g, b, a) = fillcolor(color(r, g, b, a))

"""
    nostroke()
Disable drawing the stroke.
"""
nostroke() = strokecolor(0, 0, 0, 0)

"""
    nofill()
Disable drawing the fill.
"""
nofill() = fillcolor(0, 0, 0, 0)



#      _____                  __               
#     |_   _| _ __ _ _ _  ___/ _|___ _ _ _ __  
#       | || '_/ _` | ' \(_-<  _/ _ \ '_| '  \ 
#       |_||_| \__,_|_||_/__/_| \___/_| |_|_|_|
#                                              

struct TFMatrix # no static arrays over here
    xrow::Tuple{Float64,Float64,Float64}
    yrow::Tuple{Float64,Float64,Float64}
    # has a virtual 3rd row, with a 1 at the end
end

TFMatrix(a, b, c, d, e, f) = TFMatrix((a, b, c), (d, e, f))

scale_matrix(sx, sy) = TFMatrix(sx, 0, 0, 0, sy, 0)
rotate_matrix(θ) = TFMatrix(cos(θ), -sin(θ), 0, sin(θ), cos(θ), 0)
translate_matrix(dx, dy) = TFMatrix(1, 0, dx, 0, 1, dy)

has_only_moved(m::TFMatrix) = (m.xrow[1], m.xrow[2], m.yrow[1], m.yrow[2]) == (1.0, 0.0, 0.0, 1.0)
has_rotated(m::TFMatrix) = !(m.xrow[2] == 0 == m.yrow[1])
has_translated(m::TFMatrix) = !(m.xrow[3] == 0 == m.yrow[3])
has_shear(m::TFMatrix) = !(m.xrow[1] * m.xrow[2] + m.yrow[1] * m.yrow[2] + 1 ≈ 1)

Base.:*(a::TFMatrix, b::TFMatrix) = TFMatrix(
    a.xrow[1]*b.xrow[1] + a.xrow[2]*b.yrow[1],
    a.xrow[1]*b.xrow[2] + a.xrow[2]*b.yrow[2],
    a.xrow[1]*b.xrow[3] + a.xrow[2]*b.yrow[3] + a.xrow[3], a.yrow[1] * b.xrow[1] + a.yrow[2]*b.yrow[1],
    a.yrow[1]*b.xrow[2] + a.yrow[2]*b.yrow[2],
    a.yrow[1]*b.xrow[3] + a.yrow[2]*b.yrow[3] + a.yrow[3]
)

Base.Matrix(m::TFMatrix) = [
    m.xrow[1] m.xrow[2] m.xrow[3];
    m.yrow[1] m.yrow[2] m.yrow[3];
    0 0 1
]

let stack::Vector{TFMatrix} = TFMatrix[], current::Vector{TFMatrix} = [TFMatrix(1, 0, 0, 0, 1, 0)], params::Vector{Float64} = zeros(6), params_set::Bool = false, has_transformed::Bool = false

    global function print_tf_matrix()
        m = Matrix(current[1])
        display(m)
    end

    global function clear_transform()
        empty!(stack)
        current[1] = TFMatrix(1, 0, 0, 0, 1, 0)
        params_set = false
        has_transformed = false
    end

    global function push_matrix()
        push!(stack, current)
    end

    global function pop_matrix()
        m = try
            pop!(stack)
        catch e
            println("stack is empty, pop_matrix() with no matching push_matrix()?")
            rethrow(e)
        end
        current[1] = m
    end

    global function transform(m::TFMatrix)
        current[1] = current[1] * m
    end

    global function get_matrix()
        current[1], has_transformed
    end

    global function get_params()
        if params_set
            return params
        end

        m00 = current[1].xrow[1]
        m01 = current[1].xrow[2]
        m10 = current[1].yrow[1]
        m11 = current[1].yrow[2]
        E = 0.5(m00 + m11)
        F = 0.5(m00 - m11)
        G = 0.5(m10 + m01)
        H = 0.5(m10 - m01)
        Q = sqrt(E*E + H*H)
        R = sqrt(F*F + G*G)
        params[2] = Q + R
        params[3] = Q - R
        a1 = atan(G, F)
        a2 = atan(H, E)
        params[1] = 0.5(a2 - a1)
        params[4] = 0.5(a2 + a1)
        params[5] = current[1].xrow[3]
        params[6] = current[1].yrow[3]
        params_set = true

        return params
    end

    global function tf_scale(sx, sy)
        current[1] = current[1] * scale_matrix(sx, sy)
        has_transformed = true
        params_set = false
    end

    global function tf_rotate(a)
        current[1] = current[1] * rotate_matrix(a)
        has_transformed = true
        params_set = false
    end

    global function tf_translate(dx, dy)
        current[1] = current[1] * translate_matrix(dx, dy)
        has_transformed = true
        params_set = false
    end

end

function transform(p::Point)
    tf, _ = get_matrix()
    Point(
        p.x * tf.xrow[1] + p.y * tf.xrow[2] + tf.xrow[3],
        p.x * tf.yrow[1] + p.y * tf.yrow[2] + tf.yrow[3]
    )
end

PicturaShapes.translate(dx, dy) = tf_translate(dx, dy)
PicturaShapes.scale(sx, sy) = tf_scale(sx, sy)
PicturaShapes.scale(s) = tf_scale(s, s)
PicturaShapes.rotate(a) = tf_rotate(a)



#      _       _   ___ ___ 
#     / |     /_\ | _ \_ _|
#     | |_   / _ \|  _/| | 
#     |_(_) /_/ \_\_| |___|
#                          

background(img::Image, c::PicturaColor) = Core.draw_background(img, c)

"""
    background(img::Image, x[, y, z, w])
Draw a fullscreen reactangle with color(x[, y, z, w]) into the specified image.

# Arguments
- `img::Image`: The target image buffer.
- `x`: The first color component (or a `PicturaColor`).
- `y`: The second color component (Green).
- `z`: The third color component (Blue).
- `w`: The fourth color component (Alpha).
"""
background(img::Image, rgba...) = background(img, color(rgba...))

"""
    background(x[, y, z, w])
Draw a fullscreen reactangle with color(x[, y, z, w]) into the drawing window.

# Arguments
- `x`: The first color component (or a `PicturaColor`).
- `y`: The second color component (Green).
- `z`: The third color component (Blue).
- `w`: The fourth color component (Alpha).
"""
background(rgba...) = background(Pictura.app.canvas, rgba...)



"""
    point(img::Image, x, y)
Draw a point into a specified image buffer.

# Arguments
- `img::Image`: The target image buffer.
- `x, y`: The coordinates of the point.
"""
point(img::Image, x, y) = Drawing.draw(img, Point(x, y))
point(img::Image, p) = point(img, p.x, p.y)

"""
    point(x, y)
Draw a point into the main drawing window.

# Arguments
- `x, y`: The coordinates of the point.
"""
point(x, y) = point(Pictura.app.canvas, x, y)
point(p) = point(p.x, p.y)



"""
    segment(img::Image, x1, y1, x2, y2)
Draw a (finite) line segment into a specified image buffer.

# Arguments
- `img::Image`: The target image buffer.
- `x1, y1`: The starting coordinates.
- `x2, y2`: The ending coordinates.
"""
segment(img::Image, args...) = Drawing.draw(img, Segment(args...))

"""
    segment(x1, y1, x2, y2)
Draw a (finite) line segment into the main drawing window.

# Arguments
- `x1, y1`: The starting coordinates.
- `x2, y2`: The ending coordinates.

# See also [`line`](@ref).
"""
segment(args...) = segment(Pictura.app.canvas, args...)



"""
    line(img::Image, x1, y1, x2, y2; infinite=false)
Draw a (optionally infinite) line into a specified image buffer.

# Arguments
- `img::Image`: The target image buffer.
- `x1, y1, x2, y2`: The coordinates.
- `infinite::Bool`: If `true`, draws an infinite line passing through the points. 
  If `false` (default), draws a finite segment.

# See also [`segment`](@ref).
"""
line(img::Image, x1, y1, x2, y2; infinite=false) = infinite ? Drawing.draw(img, Line(x1, y1, x2, y2)) : segment(img, x1, y1, x2, y2)
line(img::Image, a, b, c; infinite=false) = infinite ? Drawing.draw(img, Line(a, b, c)) : segment(img, a, b, c)
line(img::Image, p1, p2; infinite=false) = infinite ? Drawing.draw(img, Line(p1, p2)) : segment(img, p1, p2)

"""
    line(x1, y1, x2, y2; infinite=false)
Draw a line into the main drawing window.

# Arguments
- `x1, y1, x2, y2`: The coordinates.
- `infinite::Bool`: If `true`, draws an infinite line passing through the points. 
  If `false` (default), draws a finite segment.

# See also [`segment`](@ref).
"""
line(x1, y1, x2, y2; infinite=false) = line(Pictura.app.canvas, x1, y1, x2, y2, infinite=infinite)
line(a, b, c; infinite=false) = line(Pictura.app.canvas, a, b, c, infinite=infinite)
line(p1, p2; infinite=false) = line(Pictura.app.canvas, p1, p2, infinite=infinite)

"""
    rect(img::Image, x, y, p1, p2; <keyword arguments>)
Draw a rectangle into a specified image buffer.

# Arguments
- `img::Image`: The target image buffer.
- mode = :corner (default)
    - `x, y`: The position of the top left corner of the rectangle.
    - `p1, p2 = w, h`: The width and height.
- mode = :center
    - `x, y`: The position of the center of the rectangle.
    - `p1, p2 = w, h`: The width and height.
- mode = :radius
    - `x, y`: The position of the center of the rectangle.
    - `p1, p2 = rx, ry`: Half of the width and height.
- `corner_radius`: The radius of rounded corners.
- `angle`: The angle to rotate the rectangle by.
"""
function rect(img::Image, x, y, w, h; corner_radius=0, angle=0, mode=:corner)
    if angle == 0
        Drawing.draw(img, AxisRect(x, y, w, h, mode=mode), corner_radius)
    else
        Drawing.draw(img, Rect(x, y, w, h, angle, mode=mode), corner_radius)
    end
end
function rect(img::Image, p, w, h; corner_radius=0, angle=0, mode=:corner)
    rect(img, p.x, p.y, w, h; corner_radius=corner_radius, angle=angle, mode=mode)
end

"""
    rect(x, y, w, h; <keyword arguments>)
Draw a rectangle into the main drawing window.

# Arguments
- mode = :corner (default)
    - `x, y`: The position of the top left corner of the rectangle.
    - `p1, p2 = w, h`: The width and height.
- mode = :center
    - `x, y`: The position of the center of the rectangle.
    - `p1, p2 = w, h`: The width and height.
- mode = :radius
    - `x, y`: The position of the center of the rectangle.
    - `p1, p2 = rx, ry`: Half of the width and height.
- `corner_radius`: The radius of rounded corners.
- `angle`: The angle to rotate the rectangle by.
"""
function rect(x, y, w, h; corner_radius=0, angle=0, mode=:corner)
    rect(Pictura.app.canvas, x, y, w, h, corner_radius=corner_radius, angle=angle, mode=mode)
end
function rect(p, w, h; corner_radius=0, angle=0, mode=:corner)
    rect(Pictura.app.canvas, p.x, p.y, w, h, corner_radius=corner_radius, angle=angle, mode=mode)
end

"""
    circle(img::Image, x, y, r)
Draw a circle into a specified image buffer.

# Arguments
- `img::Image`: The target image buffer.
- `x, y`: The center coordinates.
- `r`: The radius.
"""
circle(img::Image, x, y, r) = Drawing.draw(img, Circle(x, y, r))
circle(img::Image, p, r) = Drawing.draw(img, Circle(p, r))

"""
    circle(x, y, r)
Draw a circle into the main drawing window.

# Arguments
- `x, y`: The center coordinates.
- `r`: The radius.
"""
circle(x, y, r) = circle(Pictura.app.canvas, x, y, r)
circle(p, r) = circle(Pictura.app.canvas, p, r)

"""
    ellipse(img::Image, x, y, rx, ry; angle=0)
Draw an ellipse into a specified image buffer.

# Arguments
- `img::Image`: The target image buffer.
- `x, y`: The center coordinates.
- `rx, ry`: The x and y radii.
- `angle`: The rotation angle.
"""
ellipse(img::Image, x, y, rx, ry; angle=0) = Drawing.draw(img, Ellipse(x, y, rx, ry, angle))
ellipse(img::Image, p, rx, ry; angle=0) = Drawing.draw(img, Ellipse(p, rx, ry, angle))

"""
    ellipse(x, y, rx, ry; angle=0)
Draw an ellipse into the main drawing window.

# Arguments
- `x, y`: The center coordinates.
- `rx, ry`: The x and y radii.
- `angle`: The rotation angle.
"""
ellipse(x, y, rx, ry; angle=0) = ellipse(Pictura.app.canvas, x, y, rx, ry, angle=angle)
ellipse(p, rx, ry; angle=0) = ellipse(Pictura.app.canvas, p, rx, ry, angle=angle)

"""
    image(dst::Image, src::Image; <keyword arguments>)
Draw a source image onto a destination buffer.

# Arguments
- `dst::Image`: The destination buffer.
- `src::Image`: The source image to draw.
- `src_rect`: The sub-region of the source image to use (e.g., a `Rect`). 
  If `nothing` (default), the whole image is used.
- `dst_rect`: The sub-region of the destination image to draw into. 
  If `nothing` (default), the image is drawn at the current position/size.
- `nearest_sampling::Bool`: If `true`, uses nearest-neighbor sampling. 
  If `false` (default), use linear interpolation.
"""
function image(dst::Image, src::Image; src_rect=nothing, dst_rect=nothing, nearest_sampling=false)
    Core.draw_image(dst, src, nearest_sampling=nearest_sampling, src_rect=src_rect, dst_rect=dst_rect)
end

"""
    image(src::Image; <keyword arguments>)
Draw a source image onto the main drawing window.

# Arguments
- `src::Image`: The source image to draw.
- `src_rect`: The sub-region of the source image to use.
- `dst_rect`: The sub-region of the window to draw into.
- `nearest_sampling::Bool`: If `true`, use nearest-neighbor sampling.
"""
function image(src::Image; src_rect=nothing, dst_rect=nothing, nearest_sampling=false)
    image(Pictura.app.canvas, src, src_rect=src_rect, dst_rect=dst_rect, nearest_sampling=nearest_sampling)
end





#      ___     _____                  __               
#     |_  )   |_   _| _ __ _ _ _  ___/ _|___ _ _ _ __  
#      / / _    | || '_/ _` | ' \(_-<  _/ _ \ '_| '  \ 
#     /___(_)   |_||_| \__,_|_||_/__/_| \___/_| |_|_|_|
#                                                                   

function draw(img::Pictura.Image, p::Point)
    tf, has_transformed = get_matrix()
    if !has_transformed
        return draw_no_transform(img, p)
    end

    return draw_no_transform(img, transform(p))
end


function draw(img::Pictura.Image, s::Segment)
    tf, has_transformed = get_matrix()
    if !has_transformed
        return draw_no_transform(img, s)
    end

    return draw_no_transform(img, Segment(transform(s.p1), transform(s.p2)))
end

function draw(img::Pictura.Image, l::Line)
    tf, has_transformed = get_matrix()
    s = l ∩ AxisRect(-100, -100, Pictura.width()+200, Pictura.height()+200)

    if !has_transformed
        return draw_no_transform(img, s)
    end

    s2 = Segment(transform(s.p1), transform(s.p2))
    s3 = Line(s2) ∩ AxisRect(-100, -100, Pictura.width()+200, Pictura.height()+200)
    return draw_no_transform(img, s3)

end

function draw(img::Pictura.Image, a::AxisRect, corner_radius)
    tf, has_transformed = get_matrix()
    if !has_transformed
        return draw_no_transform(img, a, corner_radius)
    end

    c = corners(a)
    tl, tr, bl, br = transform(c.tl), transform(c.tr), transform(c.bl), transform(c.br)

    if !has_rotated(tf)
        return draw_no_transform(img, AxisRect(tl, tr.x - tl.x, bl.y - tl.y, mode=:corner), corner_radius)
    end

    if !has_shear(tf)
        return draw_no_transform(img, Rect(tl=tl, tr=tr, bl=bl, br=br), corner_radius)
    end

    return draw_no_transform(img, Quatrilateral(tl, tr, br, bl), corner_radius)
end


function draw(img::Pictura.Image, r::Rect, corner_radius)
    tf, has_transformed = get_matrix()
    if !has_transformed
        return draw_no_transform(img, r, corner_radius)
    end

    if has_only_moved(tf)
        dx, dy = tf.xrow[3], tf.yrow[3]
        return draw_no_transform(img, r + Point(dx, dy))
    end

    c = corners(r)
    tl, tr, bl, br = transform(c.tl), transform(c.tr), transform(c.bl), transform(c.br)

    θ, sx, sy, ϕ, dx, dy = get_params()

    if abs(sx) ≈ abs(sy)
        return draw_no_transform(img, Rect(tl=tl, tr=tr, bl=bl, br=br), corner_radius)
    end

    return draw_no_transform(img, Quatrilateral(tl, tr, br, bl), corner_radius)

end

function draw(img::Pictura.Image, c::Circle)
    tf, has_transformed = get_matrix()
    if !has_transformed
        return draw_no_transform(img, c)
    end

    if has_only_moved(tf)
        dx, dy = tf.xrow[3], tf.yrow[3]
        return draw_no_transform(img, c + Point(dx, dy))
    end

    θ, sx, sy, ϕ, dx, dy = get_params()

    if abs(sx) ≈ abs(sy)
        return draw_no_transform(img, Circle(transform(c.center), abs(sx)*c.radius))
    end

    c2 = rotate(c, θ)
    e = scale(c2, sx, sy)
    e2 = rotate(e, ϕ)
    e3 = translate(e2, dx, dy)
    return draw_no_transform(img, e3)
end

function draw(img::Pictura.Image, e::Ellipse)
    tf, has_transformed = get_matrix()
    if !has_transformed
        return draw_no_transform(img, c)
    end

    if has_only_moved(tf)
        dx, dy = tf.xrow[3], tf.yrow[3]
        return draw_no_transform(img, e + Point(dx, dy))
    end

    θ, sx, sy, ϕ, dx, dy = get_params()

    e2 = rotate(e, θ)
    e3 = scale(e2, sx, sy)
    e4 = rotate(e3, ϕ)
    e5 = translate(e4, dx, dy)
    return draw_no_transform(img, e5)
end




#      ____    ___                  
#     |__ /   |   \ _ _ __ ___ __ __
#      |_ \_  | |) | '_/ _` \ V  V /
#     |___(_) |___/|_| \__,_|\_/\_/ 
#                                     

draw_no_transform(img::Pictura.Image, ::Nothing) = nothing

draw_no_transform(img::Pictura.Image, p::Point) = Core.draw_point(
    img, p, Pictura.strokecolor(), 0.5*Pictura.strokewidth()
)

draw_no_transform(img::Pictura.Image, s::Segment) = Core.draw_segment(
    img, s, Pictura.strokecolor(), 0.5*Pictura.strokewidth()
)

draw_no_transform(img::Pictura.Image, a::AxisRect, corner_radius=0) = Core.draw_rect(
    img, Rect(a.tl, a.w, a.h, 0.0),
    corner_radius,
    Pictura.fillcolor(),
    Pictura.strokecolor(), 0.5*Pictura.strokewidth()
)

draw_no_transform(img::Pictura.Image, r::Rect, corner_radius=0) = Core.draw_rect(
    img, r,
    corner_radius,
    Pictura.fillcolor(),
    Pictura.strokecolor(), 0.5*Pictura.strokewidth()
)

draw_no_transform(img::Pictura.Image, c::Circle) = Core.draw_ellipse(
    img, Ellipse(c.center, Point(c.radius, c.radius), 0.0),
    Pictura.fillcolor(),
    Pictura.strokecolor(), 0.5*Pictura.strokewidth()
)

draw_no_transform(img::Pictura.Image, e::Ellipse) = Core.draw_ellipse(
    img, e,
    Pictura.fillcolor(),
    Pictura.strokecolor(), 0.5*Pictura.strokewidth()
)

function draw_no_transform(img::Pictura.Image, q::Quatrilateral, corner_radius=0)
    # TODO write shader and stuff for quatrilateral
    for s in sides(q)
        draw_no_transform(img, s)
    end
end





end # module