
let m::Matrix{Float32} = zeros(Float32, 4, 4)

    function set_m()
        m[:, 1] .= 0.2126
        m[:, 2] .= 0.7152
        m[:, 3] .= 0.0722
        m[4, :] .= 0
    end

    set_m()

    global function grayscale(dst::Image, src::Image)
        mix_channels(dst, src, m, (0,0,0,1))
    end

end

function invert(dst::Image, src::Image)
    mix_channels(
        dst, src, 
        red_offset = 1.0f0,
        red_out_red_in= -1.0f0, 
        green_offset = 1.0f0,
        green_out_green_in= -1.0f0, 
        blue_offset = 1.0f0,
        blue_out_blue_in= -1.0f0, 
        alpha_offset = 1.0f0,
    ) 
end

let m::Matrix{Float32} = zeros(Float32, 3, 3)

    function set_m()
        m .= [1 2 1; 
              2 3 2; 
              1 2 1] .* (1/15)
    end

    set_m()

    global function blur(dst::Image, src::Image)
        filter(dst, src, m, 0,0,0,0,0)
    end

end

let m::Matrix{Float32} = zeros(Float32, 3, 3)

    global function erode(dst::Image, src::Image)
        filter(dst, src, m, 0, 1, 0, 0, 0)
    end

    global function dilute(dst::Image, src::Image)
        filter(dst, src, m, 1, 0, 0, 0, 0)
    end

end