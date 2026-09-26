module PicturaColors

import Colors
using Colors: red, green, blue, alpha, hue

export PicturaColor, color, red, green, blue, alpha, hue
export saturation, value, brightness, lightness, luma, intensity, luminance




struct PicturaColor
    color::UInt32 # 0xAABBGGRR
end


red_bits(c::PicturaColor) = c.color & 0x000000ff
green_bits(c::PicturaColor) = (c.color & 0x0000ff00) >> 8
blue_bits(c::PicturaColor) = (c.color & 0x00ff0000) >> 16
alpha_bits(c::PicturaColor) = c.color >> 24

function Base.show(io::IO, ::MIME"text/plain", c::PicturaColor)
    print(io, "color(", red_bits(c), ", ", green_bits(c), ", ", blue_bits(c))
    if alpha_bits(c) != 255
        print(io, ", ", alpha_bits(c))
    end
    print(io, ")")
end


#    ___             _               _
#   / __|___ _ _  __| |_ _ _ _  _ __| |_ ___ _ _ ___
#  | (__/ _ \ ' \(_-<  _| '_| || / _|  _/ _ \ '_(_-<
#   \___\___/_||_/__/\__|_|  \_,_\__|\__\___/_| /__/

color(r::UInt8, g::UInt8, b::UInt8, a::UInt8) = PicturaColor((UInt32(a) << 24) | (UInt32(b) << 16) | (UInt32(g) << 8) | r)

"""
    color(lightness::Integer)
Create a grayscale color where all components (RGB) are set to `lightness` ∈ [0, 255].
"""
color(x::Integer) = color(x, x, x)

"""
    color(luma::AbstractFloat)
Create a grayscale color from a brightness value ∈ [0.0, 1.0].
"""
function color(luma::AbstractFloat)
    l = clamp(luma, 0, 1)
    i = round(Int, 3315*l)
    g = i ÷ 13
    r = g + min((i - 13g) ÷ 3, 3)
    b = i - 9g - 3r

    return color(r, g, b)
end

"""
    color(r, g, b)
Create a color from red, green, and blue components. Alpha defaults to 1.0.

# Arguments
- `r, g, b`: Integer types are clamped to range [0, 255], floating types to range [0.0, 1.0].
"""
color(r, g, b) = color(r, g, b, 255)

"""
    color(r, g, b, a)
Create a color from red, green, blue, and alpha components.

# Arguments
- `r, g, b, a`: Integer types are clamped to range [0, 255], floating types to range [0.0, 1.0].
"""
function color(r, g, b, a)
    to_uint8(x::Integer) = UInt8(clamp(x, 0, 255))
    to_uint8(x::AbstractFloat) = UInt8(round(clamp(x, 0, 1) * 255))

    return color(to_uint8(r), to_uint8(g), to_uint8(b), to_uint8(a))
end

"""
    color(x::ColorTypes.Colorant)
PicturaColors can be created with colors from ColorTypes.jl
"""
color(c::T) where T<:Colors.Colorant = convert(PicturaColor, c)





#       ___                        _
#      / __|___ _ ___ _____ _ _ __(_)___ _ _
#     | (__/ _ \ ' \ V / -_) '_(_-< / _ \ ' \
#      \___\___/_||_\_/\___|_| /__/_\___/_||_|
#

Base.Tuple(c::PicturaColor) = (red(c), green(c), blue(c), alpha(c))
Base.Tuple(c::PicturaColor, ::Type{T}) where T<:AbstractFloat = T.(Tuple(c))
function Base.Tuple(c::PicturaColor, ::Type{T}) where T<:Integer
    return T.((red_bits(c), green_bits(c), blue_bits(c), alpha_bits(c)))
end

Base.NamedTuple(c::PicturaColor) = NamedTuple{(:r, :g, :b, :a)}(Tuple(c))
Base.NamedTuple(c::PicturaColor, ::Type{T}) where T<:AbstractFloat = NamedTuple{(:r, :g, :b, :a)}(Tuple(c, T))


function Base.convert(::Type{Colors.RGBA{Float64}}, color::PicturaColor)
    f = NamedTuple(color, Float64)
    return Colors.RGBA(f.r, f.g, f.b, f.a)
end

function Base.convert(::Type{T}, c::PicturaColor) where T<:Colors.Colorant
    rgba = convert(Colors.RGBA{Float64}, c)
    return convert(T, rgba)
end

function Base.convert(::Type{PicturaColor}, c::Colors.RGBA{Float64})
    return color(Colors.red(c), Colors.green(c), Colors.blue(c), Colors.alpha(c))
end

function Base.convert(::Type{PicturaColor}, c::T) where T<:Colors.Colorant
    c2 = convert(Colors.RGBA{Float64}, c)
    return convert(PicturaColor, c2)
end






#      _____         _ _
#     |_   _| _ __ _(_) |_ ___
#       | || '_/ _` | |  _(_-<
#       |_||_| \__,_|_|\__/__/
#

"""
    red(c::PicturaColor)::Float64
Return the red component of the color.
"""
Colors.red(c::PicturaColor) = (1/255) * red_bits(c)

"""
    green(c::PicturaColor)::Float64
Return the green component of the color.
"""
Colors.green(c::PicturaColor) = (1/255) * green_bits(c)

"""
    blue(c::PicturaColor)::Float64
Return the blue component of the color.
"""
Colors.blue(c::PicturaColor) = (1/255) * blue_bits(c)

"""
    alpha(c::PicturaColor)::Float64
Return the alpha component of the color.
"""
Colors.alpha(c::PicturaColor) = (1/255) * alpha_bits(c)




"""
    hue(c::PicturaColor)::Float64
Return the hue of a color. The result is in the range [0, 1]

# See also
[`saturation`](@ref), [`value`](@ref), [`lightness`](@ref), [`intensity`](@ref)
"""
function Colors.hue(c::PicturaColor)
    hsv = convert(Colors.HSV, c)
    return mod(hsv.h, 360) * (1/360)
end


"""
    saturation(c::PicturaColor)::Float64
Return the saturation of a color. The result is in the range [0, 1]

saturation(c) = saturation(c, Colors.HSV)
"""
saturation(c::PicturaColor) = saturation(c, Colors.HSV)

"""
    saturation(c::PicturaColor, colorspace)::Float64
Return the saturation of a color in the given color space. The result is in the range [0, 1]

# Formulas
M = max(r, g, b), m = min(r, g, b) \\
lightness: L = (M+m)/2 \\
intensity: I = (r+g+b)/3

saturation(c, Colors.HSV) = (M-m)/M \\
saturation(c, Colors.HSL) = (M-m)/(1 - abs(2L-1)) \\
saturation(c, Colors.HSI) = 1 - m/I

# See also
[`hue`](@ref), [`value`](@ref), [`lightness`](@ref), [`intensity`](@ref)
"""
function saturation(c::PicturaColor, ::Type{T}) where T<:Union{Colors.HSV,Colors.HSL,Colors.HSI}
    fmt_with_saturation = convert(T, c)
    return fmt_with_saturation.s
end


"""
    value(c::PicturaColor)::Float64
Return the value of a color. The result is in the range [0, 1]

value = max(r, g, b)

# See also
[`hue`](@ref), [`saturation`](@ref), [`lightness`](@ref), [`intensity`](@ref)
"""
function value(c::PicturaColor)
    hsv = convert(Colors.HSV, c)
    return hsv.v
end


"""
    brightness(c::PicturaColor)::Float64
Same as [`value`](@ref)
"""
brightness(c::PicturaColor) = value(c)


"""
    lightness(c::PicturaColor)::Float64
Return the lightness of a color. The result is in the range [0, 1]

M = max(r, g, b), m = min(r, g, b) \\
lightness = (M+m)/2

# See also
[`hue`](@ref), [`saturation`](@ref), [`value`](@ref), [`lightness`](@ref), [`intensity`](@ref)
"""
function lightness(c::PicturaColor)
    hsl = convert(Colors.HSL, c)
    return hsl.l
end


"""
    intensity(c::PicturaColor)::Float64
Return the intensity of a color. The result is in the range [0, 1]

intensity = (r+g+b)/3

# See also
[`hue`](@ref), [`saturation`](@ref), [`value`](@ref), [`lightness`](@ref), [`intensity`](@ref)
"""
function intensity(c::PicturaColor)
    hsi = convert(Colors.HSI, c)
    return hsi.i
end


"""
    luma(c::PicturaColor)::Float64
Returns the perceptual brightness of a color. The result is in the range [0, 1]

### Example
luma(color(0.6)) ≈ 0.6

# See also
[`luminance`](@ref), [`value`](@ref), [`lightness`](@ref), [`intensity`](@ref),
"""
function luma(c::PicturaColor)
    f = NamedTuple(c, Float64)
    return (3/13)f.r + (9/13)f.g + (1/13)f.b
end


"""
    luminance(c::PicturaColor)::Float64
Returns the physically measureable light intensity of a color. The result is in the range [0, 1]

### Example
luminance(color(0.6)) ≈ 0.3185

# See also
[`luma`](@ref), [`value`](@ref), [`lightness`](@ref), [`intensity`](@ref)
"""
function luminance(c::PicturaColor)
    xyz = convert(Colors.XYZ, c)
    return xyz.y
end



#       ___              _          ___     _
#      / __|_ _ ___ __ _| |_ ___   / __|___| |___ _ _
#     | (__| '_/ -_) _` |  _/ -_) | (__/ _ \ / _ \ '_|
#      \___|_| \___\__,_|\__\___|  \___\___/_\___/_|
#

function color(basecolor::PicturaColor=color(1.0, 0, 0);
    hue=nothing,
    hue_hsv=hue,
    hue_hsi=nothing,
    hue_hsl=nothing,
    saturation=nothing,
    saturation_hsv=saturation,
    saturation_hsi=nothing,
    saturation_hsl=nothing,
    brightness=nothing,
    value=brightness,
    intensity=nothing,
    lightness=nothing,
)

    ALPHA = alpha_bits(basecolor)

    if !isnothing(value)
        hsv = convert(Colors.HSV, basecolor)
        basecolor = color(Colors.HSV(hsv.h, hsv.s, value))
    end

    if !isnothing(intensity)
        hsi = convert(Colors.HSI, basecolor)
        basecolor = color(Colors.HSI(hsi.h, hsi.s, intensity))
    end

    if !isnothing(lightness)
        hsl = convert(Colors.HSL, basecolor)
        basecolor = color(Colors.HSL(hsl.h, hsl.s, lightness))
    end



    if !isnothing(saturation_hsv)
        hsv = convert(Colors.HSV, basecolor)
        basecolor = color(Colors.HSV(hsv.h, saturation_hsv, hsv.v))
    end

    if !isnothing(saturation_hsi)
        hsi = convert(Colors.HSI, basecolor)
        basecolor = color(Colors.HSI(hsi.h, saturation_hsi, hsi.i))
    end

    if !isnothing(saturation_hsl)
        hsl = convert(Colors.HSL, basecolor)
        basecolor = color(Colors.HSL(hsl.h, saturation_hsl, hsl.l))
    end



    if !isnothing(hue_hsv)
        hsv = convert(Colors.HSV, basecolor)
        basecolor = color(Colors.HSV(360*hue, hsv.s, hsv.v))
    end

    if !isnothing(hue_hsi)
        hsi = convert(Colors.HSI, basecolor)
        basecolor = color(Colors.HSI(360*hue, hsi.s, hsi.i))
    end

    if !isnothing(hue_hsl)
        hsl = convert(Colors.HSL, basecolor)
        basecolor = color(Colors.HSL(360*hue, hsl.s, hsl.l))
    end


    return color(red_bits(basecolor), green_bits(basecolor), blue_bits(basecolor), ALPHA)

end



end
