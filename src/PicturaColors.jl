module PicturaColors

export color, red, green, blue
export PicturaColor, floats

import Colors

struct PicturaColor
    color::UInt32 # 0xAABBGGRR
end

red(c::PicturaColor)   =  c.color & 0x000000ff
green(c::PicturaColor) = (c.color & 0x0000ff00) >> 8
blue(c::PicturaColor)  = (c.color & 0x00ff0000) >> 16
alpha(c::PicturaColor) = (c.color & 0xff000000) >> 24

to_float(x::Integer) = clamp(x, 0, 255) * (1/255)
to_float(x::AbstractFloat) = clamp(x, 0, 1)

to_char(x::Integer) = UInt8(clamp(x, 0, 255))
to_char(x::AbstractFloat) = UInt8(round(clamp(x, 0, 1) * 255))

color(r::UInt8, g::UInt8, b::UInt8, a::UInt8) = PicturaColor(r | (UInt32(g) << 8) | (UInt32(b) << 16) | (UInt32(a) << 24))

color(x) = color(x, x, x)

function color(l::AbstractFloat)
    l = clamp(l, 0, 1)
    i = round(Int, 3315*l)
    g = i ÷ 13
    r = g + min((i - 13g) ÷ 3, 3)
    b = i - 9g - 3r

    return color(r, g, b)
end

color(r, g, b) = color(r, g, b, 1.0)
color(r, g, b, a) = color(to_char(r), to_char(g), to_char(b), to_char(a))

function color(c::T) where T <: Colors.Colorant
    convert(PicturaColor, c)
end


floats(c::PicturaColor, F=Float64) = (
    r=F(to_float(red(c))), 
    g=F(to_float(green(c))), 
    b=F(to_float(blue(c))), 
    a=F(to_float(alpha(c)))
)

function luminance(c::PicturaColor)
    f = floats(c)
    return 0.2126f.r + 0.7152f.g + 0.0722f.b
end

function Base.convert(::Type{Colors.RGBA{Float64}}, c::PicturaColor)
    f = floats(c)
    return Colors.RGBA(f.r, f.g, f.b, f.a) 
end

function Base.convert(::Type{T}, c::PicturaColor) where T <: Colors.Colorant
    c2 = convert(Colors.RGBA{Float64}, c)
    return convert(T, c2)
end

function Base.convert(::Type{PicturaColor}, c::Colors.RGBA{Float64})
    return color(Colors.red(c), Colors.green(c), Colors.blue(c), Colors.alpha(c))
end

function Base.convert(::Type{PicturaColor}, c::T) where T <: Colors.Colorant
    c2 = convert(Colors.RGBA{Float64}, c)
    return convert(PicturaColor, c2)
end

end

