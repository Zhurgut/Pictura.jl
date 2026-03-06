module Drawing

import ..Pictura
using PicturaShapes

struct TFMatrix # no static arrays over here
    xrow::Tuple{Float64, Float64, Float64}
    yrow::Tuple{Float64, Float64, Float64}
    # has a virtual 3rd row, with a 1 at the end
end

TFMatrix(a, b, c, d, e, f) = TFMatrix((a, b, c), (d, e, f))

scale_matrix(sx, sy) = TFMatrix(sx, 0, 0, 0, sy, 0)
rotate_matrix(θ)     = TFMatrix(cos(θ), -sin(θ), 0, sin(θ), cos(θ), 0)
translate_matrix(dx, dy) = TFMatrix(1, 0, dx, 0, 1, dy)

has_only_moved(m::TFMatrix) = (m.xrow[1], m.xrow[2], m.yrow[1], m.yrow[2]) == (1.0, 0.0, 0.0, 1.0)
has_rotated(m::TFMatrix) = !(m.xrow[2] == 0 == m.yrow[1])
has_translated(m::TFMatrix) = !(m.xrow[3] == 0 == m.yrow[3])

Base.:*(a::TFMatrix, b::TFMatrix) = TFMatrix(
    a.xrow[1]*b.xrow[1] + a.xrow[2]*b.yrow[1], 
    a.xrow[1]*b.xrow[2] + a.xrow[2]*b.yrow[2], 
    a.xrow[1]*b.xrow[3] + a.xrow[2]*b.yrow[3] + a.xrow[3],

    a.yrow[1]*b.xrow[1] + a.yrow[2]*b.yrow[1], 
    a.yrow[1]*b.xrow[2] + a.yrow[2]*b.yrow[2], 
    a.yrow[1]*b.xrow[3] + a.yrow[2]*b.yrow[3] + a.yrow[3]
)

Base.Matrix(m::TFMatrix) = [
    m.xrow[1] m.xrow[2] m.xrow[3];
    m.yrow[1] m.yrow[2] m.yrow[3];
    0 0 1
]

let stack::Vector{TFMatrix} = TFMatrix[],
    current::Vector{TFMatrix} = [TFMatrix(1, 0, 0, 0, 1, 0)],
    params::Vector{Float64} = zeros(6),
    params_set::Bool = false,
    has_transformed::Bool = false

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



draw_no_transform(img::Pictura.Image, p::Point) = Pictura.draw_point(
    img, p, Pictura.strokecolor(), 0.5*Pictura.strokewidth()
)
draw_no_transform(img::Pictura.Image, s::Segment) = Pictura.draw_segment(
    img, s, Pictura.strokecolor(), 0.5*Pictura.strokewidth()
)
draw_no_transform(img::Pictura.Image, a::AxisRect, corner_radius=0) = Pictura.draw_rect(
    img, Rect(a.tl, a.w, a.h, 0.0), 
    corner_radius, 
    Pictura.fillcolor(),
    Pictura.strokecolor(), 0.5*Pictura.strokewidth()
)
draw_no_transform(img::Pictura.Image, r::Rect, corner_radius=0) = Pictura.draw_rect(
    img, r, 
    corner_radius, 
    Pictura.fillcolor(),
    Pictura.strokecolor(), 0.5*Pictura.strokewidth()
)
draw_no_transform(img::Pictura.Image, c::Circle) = Pictura.draw_ellipse(
    img, Ellipse(c.center, Point(c.radius, c.radius), 0.0), 
    Pictura.fillcolor(),
    Pictura.strokecolor(), 0.5*Pictura.strokewidth()
)
draw_no_transform(img::Pictura.Image, e::Ellipse) = Pictura.draw_ellipse(
    img, e, 
    Pictura.fillcolor(),
    Pictura.strokecolor(), 0.5*Pictura.strokewidth()
)

function draw(img::Pictura.Image, p::Point)
    tf, has_transformed = get_matrix()
    if !has_transformed
        return draw_no_transform(img, p)
    end

    if has_only_moved(tf)
        dx, dy = tf.xrow[3], tf.yrow[3]
        return draw_no_transform(img, p + Point(dx, dy))
    end

    if !has_rotated(tf)
        sx, sy = tf.xrow[1], tf.yrow[2]
        dx, dy = tf.xrow[3], tf.yrow[3]
        p2 = scale(p, sx, sy) + Point(dx, dy)

        return draw_no_transform(img, p2)
    end

    θ, sx, sy, ϕ, dx, dy = get_params()

    p2 = rotate(p, θ)
    p3 = scale(p2, sx, sy)
    p4 = rotate(p3, ϕ)
    p5 = translate(p4, dx, dy)
    return draw_no_transform(img, p5)
end


function draw(img::Pictura.Image, s::Segment)
    tf, has_transformed = get_matrix()
    if !has_transformed
        return draw_no_transform(img, s)
    end

    if has_only_moved(tf)
        dx, dy = tf.xrow[3], tf.yrow[3]
        return draw_no_transform(img, s + Point(dx, dy))
    end

    if !has_rotated(tf)
        sx, sy = tf.xrow[1], tf.yrow[2]
        dx, dy = tf.xrow[3], tf.yrow[3]
        p2 = scale(s, sx, sy) + Point(dx, dy)

        return draw_no_transform(img, p2)
    end

    θ, sx, sy, ϕ, dx, dy = get_params()

    s2 = rotate(s, θ)
    s3 = scale(s2, sx, sy)
    s4 = rotate(s3, ϕ)
    s5 = translate(s4, dx, dy)
    return draw_no_transform(img, s5)
end

function draw(img::Pictura.Image, l::Line)
    tf, has_transformed = get_matrix()
    if !has_transformed
        s = l ∩ AxisRect(-100, -100, Pictura.width()+200, Pictura.height()+200)
        return draw_no_transform(img, s)
    end

    θ, sx, sy, ϕ, dx, dy = get_params()

    l2 = rotate(l, θ)
    l3 = scale(l2, sx, sy)
    l4 = rotate(l3, ϕ)
    l5 = translate(l4, dx, dy)
    s = l5 ∩ AxisRect(-100, -100, Pictura.width()+200, Pictura.height()+200)
    return draw_no_transform(img, s)

end

function draw(img::Pictura.Image, a::AxisRect, corner_radius)
    tf, has_transformed = get_matrix()
    if !has_transformed
        return draw_no_transform(img, a, corner_radius)
    end

    if has_only_moved(tf)
        dx, dy = tf.xrow[3], tf.yrow[3]
        return draw_no_transform(img, a + Point(dx, dy), corner_radius)
    end

    if !has_rotated(tf)
        sx, sy = tf.xrow[1], tf.yrow[2]
        dx, dy = tf.xrow[3], tf.yrow[3]
        a2 = scale(a, sx, sy) + Point(dx, dy)

        return draw_no_transform(img, a2, 0.5*(abs(sx) + abs(sy)) * corner_radius)
    end

    θ, sx, sy, ϕ, dx, dy = get_params()

    if abs(sx) ≈ abs(sy)
        r = rotate(a, θ)
        r2 = sx * r
        r3 = rotate(r2, ϕ)
        r4 = translate(r3, dx, dy)
        return draw_no_transform(img, r4, sx * corner_radius)
    end

    r = rotate(a, θ)
    q = scale(r, sx, sy)
    q2 = rotate(q, ϕ)
    q3 = translate(q2, dx, dy)
    return draw_no_transform(img, q3, 0.5*(abs(sx) + abs(sy)) * corner_radius)

end


function draw(img::Pictura.Image, a::Rect, corner_radius)
    tf, has_transformed = get_matrix()
    if !has_transformed
        return draw_no_transform(img, a, corner_radius)
    end

    if has_only_moved(tf)
        dx, dy = tf.xrow[3], tf.yrow[3]
        return draw_no_transform(img, a + Point(dx, dy))
    end

    θ, sx, sy, ϕ, dx, dy = get_params()

    if abs(sx) ≈ abs(sy)
        r = rotate(a, θ)
        q = scale(r, sx, sy)
        r2 = simplify(q)
        @assert typeof(r2) == Rect
        r3 = rotate(r2, ϕ)
        r4 = translate(r3, dx, dy)
        return draw_no_transform(img, r4, sx * corner_radius)
    end

    r = rotate(a, θ)
    q = scale(r, sx, sy)
    q2 = rotate(q, ϕ)
    q3 = translate(q2, dx, dy)
    return draw_no_transform(img, q3, 0.5*(abs(sx) + abs(sy)) * corner_radius)

end

function draw(img::Pictura.Image, c::Circle)
    tf, has_transformed = get_matrix()
    if !has_transformed
        return draw_now_transform(img, c)
    end

    if has_only_moved(tf)
        dx, dy = tf.xrow[3], tf.yrow[3]
        return draw_no_transform(img, c + Point(dx, dy))
    end

    θ, sx, sy, ϕ, dx, dy = get_params()

    if abs(sx) ≈ abs(sy)
        c2 = rotate(c, θ)
        e = scale(c2, sx, sy)
        c3 = Circle(e.center, e.radius.x)
        c4 = rotate(c3, ϕ)
        c5 = translate(c4, dx, dy)
        return draw_no_transform(img, c5)
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





end # module