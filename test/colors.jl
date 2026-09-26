using Pictura
using Test
import Colors


@testset "color components" begin
    spaces = [
        Colors.HSV, Colors.HSL, Colors.HSI,
    ]

    functions = [Colors.hue, value, brightness, intensity, lightness, luma, luminance]
    two_arg_functions = [saturation]

    colors = [color(0.0), color(1.0), color(127), color(255, 0, 0), color(255, 0, 1), color(0, 0, 255), color(255, 0, 255)]

    mins = fill(10.0, length(functions))
    maxs = fill(-10.0, length(functions))

    for (i, f) in enumerate(functions)
        for c in colors
            val = f(c)
            mins[i] = min(val, mins[i])
            maxs[i] = max(val, maxs[i])
        end
        for _=1:1000
            c = color(rand(Colors.RGBA))
            val = f(c)
            mins[i] = min(val, mins[i])
            maxs[i] = max(val, maxs[i])
        end
    end

    display(mins)
    display(maxs)

    mins = fill(10.0, length(spaces), length(two_arg_functions))
    maxs = fill(-10.0, length(spaces), length(two_arg_functions))

    for (i, f) in enumerate(two_arg_functions), (j, s) in enumerate(spaces)
        for c in colors
            try
                val = f(c, s)
                mins[j, i] = min(val, mins[j, i])
                maxs[j, i] = max(val, maxs[j, i])
            catch e
            end
        end
        for _=1:100
            c = color(rand(Colors.RGBA))
            try
                val = f(c, s)
                mins[j, i] = min(val, mins[j, i])
                maxs[j, i] = max(val, maxs[j, i])
            catch e
            end
        end
    end

    display(mins)
    display(maxs)
end