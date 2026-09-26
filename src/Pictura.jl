module Pictura







include("PicturaLib.jl")
using .PicturaLib
export DELETE, RIGHT, LEFT, DOWN, UP, SHIFT, CTRL, ALT, HOME, END, PAGEUP, PAGEDOWN, INSERT

Base.map(x::Real, a::Real, b::Real, A::Real, B::Real) = fma(x, B-A, fma(A, b, -B*a)) * (1 / (b-a))


using PicturaShapes




include("PicturaColors.jl")
using .PicturaColors
export color, red, green, blue, alpha, hue
export saturation, value, brightness, lightness, luma, intensity, luminance


include("image.jl")
export Image


include("Core.jl")
using .Core
export mouse, noloop, framerate, frametime, framecount
export render_present, @pictura, setup, @drawloop



app::App = App()




include("Callbacks.jl")
using .Callbacks
export @mousepressed, @mousereleased, @mousemoved, @mousedragged, @mousewheel, @keypressed, @keyreleased
export CENTER, MIDDLE, WHEEL, MOUSEWHEEL, ENTER, BACK, BACKSPACE, TAB, SPACE, SPACEBAR, COMMA, PERIOD




include("filters.jl")




#      _  _
#     | || |_ __  _ __
#     | __ | '  \| '  \ _ _ _
#     |_||_|_|_|_|_|_|_(_|_|_)
#
export loadpixels, updatepixels, pixels, width, height

width() = width(app.canvas)
height() = height(app.canvas)

loadpixels() = loadpixels(app.canvas)
updatepixels() = updatepixels(app.canvas)
pixels() = pixels(app.canvas)







include("Drawing.jl")
using .Drawing
export strokecolor, strokewidth, nostroke, fillcolor, nofill
export transform, translate, scale, rotate
export draw, background, point, segment, line, rect, circle, ellipse, image


include("io.jl")
export load_image, save_image, save_frame




end # module Pictura
