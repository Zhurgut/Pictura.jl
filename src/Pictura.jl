module Pictura


include("picturalib.jl")

PicturaLib.init(500, 500)
PicturaLib.draw_background(PicturaLib.get_canvas(), Float32(17 / 255), Float32(183 / 255), Float32(209 / 255), Float32(1.0))
PicturaLib.present()
PicturaLib.delay(1000000000)
PicturaLib.quit()

end # module Pictura
