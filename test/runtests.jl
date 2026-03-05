using Pictura
using Test
using BenchmarkTools
using ProceduralNoise
using PicturaShapes



let
    setup(size(600, 400))

    @mousepressed begin
        BUTTON == LEFT && print("l")
        BUTTON == "left" && print("e")
        BUTTON == :l && print("f")
        BUTTON == 'l' && println("t")

        BUTTON == RIGHT && print("r")
        BUTTON == "right" && print("i")
        BUTTON == :r && print("g")
        BUTTON == "r" && print("h")
        BUTTON == 'r' && println("t")

        BUTTON == MOUSEWHEEL && print("m")
        BUTTON == CENTER && print("i")
        BUTTON == "middle" && print("d")
        BUTTON == :m && print("d")
        BUTTON == "wheel" && print("l")
        BUTTON == 'm' && println("e")
    end

    keys = [DELETE, RIGHT, LEFT, DOWN, UP, SHIFT, CTRL, ALT, HOME, END, PAGEUP, PAGEDOWN, INSERT, ENTER, BACK, BACKSPACE, TAB, SPACE, SPACEBAR, COMMA, PERIOD]
    strings = ["delete", "right", "left", "down", "up", "shift", "ctrl", "alt", "home", "end", "pageup", "pagedown", "insert", "enter", "back", "backspace", "tab", "space", "spacebar", "comma", "period"]

    @keypressed begin
        for i=0:255
            if Char(i) == KEY
                display(Char(i))
            end
            if i < 10 && i == KEY
                println("hi $i")
            end
        end
        for i=1:length(keys)
            if KEY == keys[i]
                println(strings[i])
            end
        end
    end

    @drawloop begin

    end

end

begin
    s = 1
    shapes = [
        ()->Point(mouse().x, mouse().y),
        ()->Segment(width()/2, height()/2, mouse().x, mouse().y),
        ()->AxisRect(width()*0.5, height()*0.5, abs(mouse().x - width()*0.5),  abs(mouse().y - height()*0.5), mode=:radius),
        ()->Rect(width()*0.5, height()*0.5, 100, 50, angle(mouse().pos - Point(width()*0.5, height()*0.5))),
        ()->Circle(mouse().pos, 100),
        ()->Ellipse(mouse().pos, Point(width()*0.5, height()*0.5), 0.5sdf(Point(width()*0.5, height()*0.5), mouse().pos)+10)
    ]

    setup(
        size(500, 300)
    )

    @mousepressed begin
        global s
        s = s % length(shapes) + 1
    end

    @drawloop begin
        S = shapes[s]()
        for r=1:height(), c=1:width()
            pixels()[r, c] = color(0.005abs(sdf(S, Point(c, r))))
        end
        updatepixels()
        B = rotate(bounding_box(S, 10), 0.0)
        Pictura.draw_rect(Pictura.app.canvas, B, 0, color(0,0,0,0), color(255, 0,  0), 0.2)
    end
end


begin

    setup(size(500, 500))

    Pictura.draw_background(Pictura.app.canvas, color(0.3, 0.5, 0.7))
    strokecolor(0)

    a = 4

    # Pictura.Callbacks.eval(quote
    #     function on_mouse_pressed(x, y, k)
    #         begin
    #             println("hi") 
    #         end
    #     end
    # end)

    @mousepressed begin
        global a
        println("ho$a, $BUTTON")
        a += 1
        if a > 6
            @mousepressed begin
                println("he$(mouse().pos)")
            end
        end
    end

    @mousedragged begin
        println(mouse().pos - mouse().prev)
    end

    @keypressed begin
        println(KEYCODE)
    end

    println(Pictura.Callbacks.on_mouse_pressed)
    
    println("hey")
    println("hi0")
    @drawloop begin
        Pictura.draw_point(Pictura.app.canvas, mouse().pos, strokecolor(), 4)
    end

end

function draw_noise(t, s)
    loadpixels()

    T = 1
    Threads.@threads for trd=1:T
        R = height() ÷ T
        for r = (trd-1)*R+1:trd*R
            # println("$(Threads.threadid()): $r")
            for c = 1:width()
                # pixels(Pictura.app.canvas)[r, c] = color(random_noise(r * 0.02 - t, c * 0.02, t))

                # pixels(Pictura.app.canvas)[r, c] = color(perlin_noise(r * 0.04 - t, c * 0.04, t, cache_index=trd))

                # if mouse().l
                #     pixels(Pictura.app.canvas)[r, c] = color((0.25 .* perlin_noise(c * s, r * s, t, t, gradient=true)[1:2] .+ 0.5)..., 1.0)
                # else
                #     pixels(Pictura.app.canvas)[r, c] = color(perlin_noise(c * s, r * s, t, t))
                # end

                # wn = worley_noise(r * 0.02, c * 0.02, t, cache_index=trd)
                # pixels(Pictura.app.canvas)[r, c] = color(2*(wn[2] - wn[1]))

                # pixels(Pictura.app.canvas)[r, c] = color(worley_noise1(r * 0.02, c * 0.02, t, cache_index=trd))

                # sn = sim_noise2d(r * 0.02, c * 0.02, t)
                # pixels(Pictura.app.canvas)[r, c] = color(0.5sn[1]+0.5, 0.5sn[2]+0.5, 1.0)

                # sn = sim_noise3d(r * 0.03, c * 0.03, t, t)
                # pixels()[r, c] = color(0.5sn[1]+0.5, 0.5sn[2]+0.5, 0.5sn[3]+0.5)

                # sn = curl_noise(r * 0.03, c * 0.03, 0.5, t)
                # pixels()[r, c] = color(0.5sn[1]+0.5, 0.5sn[2]+0.5, 0.5sn[3]+0.5)

                # sn = 2 .* bitangent_noise(r * 0.03, c * 0.03, t, t, f2=value_noise)
                # pixels()[r, c] = color(0.5sn[1]+0.5, 0.5sn[2]+0.5, 0.5sn[3]+0.5)

                # sn = fractal(sim_noise2d, r * 0.02, c * 0.02, t)
                # pixels(Pictura.app.canvas)[r, c] = color(0.5sn[1]+0.5, 0.5sn[2]+0.5, 1.0)

                # pixels(Pictura.app.canvas)[r, c] = color(fractal(value_noise, r * 0.02, c * 0.02, t))

                # if c > width() / 2 
                #     pixels(Pictura.app.canvas)[r, c] = color(fractal(random_noise, r * 0.02, c * 0.02, t))
                # else
                #     pixels(Pictura.app.canvas)[r, c] = color(random_noise(r * 0.02, c * 0.02, t))
                # end

                # if c > width() / 2 
                #     pixels(Pictura.app.canvas)[r, c] = color(fractal(value_noise, r * 0.02, c * 0.02, t))
                # else
                #     pixels(Pictura.app.canvas)[r, c] = color(value_noise(r * 0.02, c * 0.02, t))
                # end

                # if c > width() / 2 
                #     pixels(Pictura.app.canvas)[r, c] = color(fractal(perlin_noise, r * 0.02, c * 0.02, t))
                # else
                #     pixels(Pictura.app.canvas)[r, c] = color(perlin_noise(r * 0.02, c * 0.02, t))
                # end

                # if c > width() / 2 
                #     pixels(Pictura.app.canvas)[r, c] = color(fractal(worley_noise1, r * 0.02, c * 0.02))
                # else
                #     pixels(Pictura.app.canvas)[r, c] = color(worley_noise1(r * 0.02, c * 0.02))
                # end

                if c < width() / 3 
                    pixels(Pictura.app.canvas)[r, c] = color(map.(value_noise(r * 0.02, c * 0.02, t, gradient=true)[1:2], -1.5, 1.5, 0, 1)..., 1.0)
                elseif c < 2width() / 3 
                    pixels(Pictura.app.canvas)[r, c] = color(map.(perlin_noise(r * 0.02, c * 0.02, gradient=true)[1:2], -2, 2, 0, 1)..., 1.0)
                    
                else
                    pixels(Pictura.app.canvas)[r, c] = color(map.(fractal(worley_noise2, r * 0.02, c * 0.02, t, t, gradient=true)[1:2], -1, 1, 0, 1)..., 1.0)
                end

                
                # wn = if c > width() / 2 
                #     w2 = fractal(worley_noise2, r * 0.02, c * 0.02, t)
                #     w1 = fractal(worley_noise1, r * 0.02, c * 0.02, t)
                #     (w1, w2)
                # else
                #     w2 = worley_noise2(r * 0.02, c * 0.02, t)
                #     w1 = worley_noise1(r * 0.02, c * 0.02, t)
                #     (w1, w2)
                # end
                # pixels(Pictura.app.canvas)[r, c] = color(2*(wn[2] - wn[1]))

            end
        end
    end

    updatepixels()
end

@testset "noise and pixels" begin
    setup(size(500, 300))
    

    t = 0.0

    @drawloop begin
        Pictura.draw_background(Pictura.app.canvas, color(1.0, 0, 0))

        draw_noise(t, 0.02)

        t += 0.01

        if rand() < 0.1 println(framerate()) end
    end
end

@testset "flow fields" begin
    w,h = 500, 300
    setup(size(w, h))
    framerate(40)

    t = 0.0
    v = 1
    s = 0.015

    points = [scale(Point(rand(), rand()), w, h) for i=1:1000]

    @drawloop begin
        Pictura.draw_background(Pictura.app.canvas, color(0.0, 0.0, 0.0, 0.02))
        println(framerate())

        for (i, p) in enumerate(points)

            if p ∈ AxisRect(-200, -200, width()+400, height()+400)
                old_p = p

                if p.x < width()/2
                    k1 = Point(sim_noise2d(p.x * s, p.y * s))
                    p2 = points[i] + 0.5v * k1
                    flow = Point(sim_noise2d(p2.x * s, p2.y * s))
                else
                    k1 = Point(fractal(sim_noise2d, p.x * s, p.y * s))
                    p2 = points[i] + 0.5v * k1
                    flow = Point(fractal(sim_noise2d, p2.x * s, p2.y * s))
                end

                

                # k1 = 2 * Point(perlin_noise(p.x * s, p.y * s, 1), perlin_noise(p.x * s, p.y * s, 10, thread_idx=2)) + Point(-1, -1)
                # p2 = points[i] + 0.5v * k1
                # flow = 2 * Point(perlin_noise(p2.x * s, p2.y * s, 1), perlin_noise(p2.x * s, p2.y * s, 10, thread_idx=2)) + Point(-1, -1)

                # k1 = Point(fractal(sim_noise2d, p.x * s, p.y * s, t))
                # p2 = points[i] + 0.5v * k1
                # flow = Point(fractal(sim_noise2d, p2.x * s, p2.y * s, t))

                # k1 = Point(sim_noise3d(p.x * s, p.y * s, t)[1:2])
                # p2 = points[i] + 0.5v * k1
                # flow = Point(sim_noise3d(p2.x * s, p2.y * s, t)[1:2])

                # k1 = Point(curl_noise(p.x * s, p.y * s, t)[1:2])
                # p2 = points[i] + 0.5v * k1
                # flow = Point(curl_noise(p2.x * s, p2.y * s, t)[1:2])

                # k1 = Point(fractal(sim_noise2d, p.x * s, p.y * s, t))
                # p2 = points[i] + 0.5v * k1
                # flow = Point(fractal(sim_noise2d, p2.x * s, p2.y * s, t))

                points[i] += v * flow

                Pictura.draw_segment(Pictura.app.canvas, Segment(old_p, points[i]), color(255), 0.5)
            else
                points[i] = scale(Point(rand(), rand()), width(), height())
            end

        end

        t += 0.003

    end
end

@testset "gradients" begin
    w,h = 600, 400
    setup(size(w, h))
    framerate(40)

    t = 0.0
    v = 2.0
    s = 0.02

    points = [scale(Point(rand(), rand()), w, h) for i=1:1000]

    @drawloop begin
        
        t = framecount() * 0.01
        draw_noise(t, s)

        for (i, p) in enumerate(points)

            if p ∈ AxisRect(-200, -200, width()+400, height()+400)
                old_p = p

                dx, dy = perlin_noise(s * p.x, s * p.y, t, t, gradient=true)[1:2]
                flow = Point(dx, dy) + 0.1Point(randn(), randn())

                points[i] += v * flow

                Pictura.draw_segment(Pictura.app.canvas, Segment(old_p, points[i]), color(255), 1)
            else
                points[i] = scale(Point(rand(), rand()), width(), height())
            end

        end

    end
end

@testset "divergence" begin
    w,h = 600, 400
    setup(size(w, h))
    framerate(40)

    t = 0.0
    v = 6
    s = 0.02

    δ = 1e-6


    @drawloop begin
        Pictura.draw_background(Pictura.app.canvas, color(0.0, 0.0, 0.0, 0.1))
        println(framerate())

        for r=1:height(), c=1:width()

            # P, Q = sim_noise2d(c*s, r*s, t)
            # dPdx = (P - sim_noise2d(c*s+δ, r*s, t)[1]) / δ
            # dQdy = (Q - sim_noise2d(c*s, r*s+δ, t)[2]) / δ
            # div = dPdx + dQdy

            # P, Q, R = sim_noise3d(c*s, r*s, t, t)
            # dPdx = (P - sim_noise3d(c*s+δ, r*s, t, t)[1]) / δ
            # dQdy = (Q - sim_noise3d(c*s, r*s+δ, t, t)[2]) / δ
            # dRdz = (R - sim_noise3d(c*s, r*s, t+δ, t)[3]) / δ
            # div = dPdx + dQdy + dRdz

            # P, Q, R = curl_noise(c*s, r*s, t)
            # dPdx = (P - curl_noise(c*s+δ, r*s, t)[1]) / δ
            # dQdy = (Q - curl_noise(c*s, r*s+δ, t)[2]) / δ
            # dRdz = (R - curl_noise(c*s, r*s, t+δ)[3]) / δ
            # div = dPdx + dQdy + dRdz

            P, Q, R = bitangent_noise(c*s, r*s, t, t)
            dPdx = (P - bitangent_noise(c*s+δ, r*s, t, t)[1]) / δ
            dQdy = (Q - bitangent_noise(c*s, r*s+δ, t, t)[2]) / δ
            dRdz = (R - bitangent_noise(c*s, r*s, t+δ, t)[3]) / δ
            div = dPdx + dQdy + dRdz

            # # not divergence free!
            # P, Q, R = perlin_noise(c*s, r*s, t, gradient=true)
            # dPdx = (P - perlin_noise(c*s+δ, r*s, t, gradient=true)[1]) / δ
            # dQdy = (Q - perlin_noise(c*s, r*s+δ, t, gradient=true)[2]) / δ
            # dRdz = (R - perlin_noise(c*s, r*s, t+δ, gradient=true)[3]) / δ
            # div = dPdx + dQdy + dRdz

            pixels(Pictura.app.canvas)[r, c] = color(div + 0.5)
        end

        t += 0.03

        updatepixels()

    end

    
end






















@testset "stability" begin
    for i=1:100
        print("$i, ")
        setup(
            size(600, 400)
        )

        
    end
end

@testset "some shapes" begin # weird bug, stroke is like 30x too thick for circle and ellipse
    @setup begin
        size(900, 600)
        strokecolor(0)
        strokewidth(2)
        # nostroke()
    end

    println(strokewidth())

    x,y = 0.0,0.0

    @drawloop begin
        background(255)
        fillcolor(255, 0, 0)
        ellipse(100, 100, 50, 50)
        fillcolor(0, 255, 0)
        rect(200+x, 100+y, 100, 50)
        fillcolor(0, 0, 255)
        ellipse(400, 400, 70, 30, framecount() / 200)
        x += randn()
        y += randn()
    end
end

@testset "bounding_boxes and intersects" begin

    # issue with edges probably because of issues with dist function of quatrilateral

    @setup begin
        size(900, 600)
        strokecolor(0)
        fillcolor(0, 200, 200, 50)
        strokewidth(5)
        framerate(100)
    end

    @drawloop begin
        background(255)

        scale(1 + 0.05*sin(framecount()/50), 1 + 0.05*cos(framecount()/50))
        translate(5, 10)
        rotate(0.01 * sin(framecount()/30))

        angle = framecount() / 32
        shapes = (
            Line(200, 0, 0, 200),
            Segment(0, 400, 200, 600),
            AxisRect(450, 150, 100, 50, mode=:radius),
            Rect(450, 450, 100, 50, angle, mode=:radius), 
            Circle(750, 150, 100),
            Ellipse(750, 450, 100, 50, angle)
        )

        strokecolor(0)
        draw.(shapes)

        HLine = Pictura.Rendering.HLine
        VLine = Pictura.Rendering.VLine

        lines = (
            HLine(100), HLine(150), HLine(400), HLine(450),
            VLine(150), VLine(350), VLine(450), VLine(350), VLine(450), VLine(650), VLine(750), VLine(800)
        )

        strokecolor(0, 255, 0, 50)
        for l in lines
            draw(Line(l))
        end

        strokecolor(255, 0, 0)
        for s in shapes, l in lines
            draw(s ∩ l)
        end

        strokecolor(0, 0, 255, 50)
        l = Point(width()/2, height()/2) + Line(angle/6, 0)
        draw(l)
        strokecolor(0, 0, 255)
        for s in shapes
            draw(l ∩ s)
        end

        if framecount() % 100 == 0
            Pictura.FrameRateManager.info()
        end
    end
end

@testset "error catching" begin
    @setup begin
        size(800, 600)
        background(1.0, 0.2, 0.3)
    end

    @drawloop begin
        if framecount() == 200
            sqrt(-45)
        end
    end
end


@testset "error catching2" begin
    @setup begin
        size(800, 600)
        background(1.0, 0.2, 0.3)
        sqrt(-45)
    end

    @drawloop begin
        if framecount() == 200
            sqrt(-45)
        end
    end
end

@testset "image rendering" begin
    @setup begin
        size(1000, 500)
        framerate(20)
    end

    img = Image("C:/Users/damia/.julia/dev/Pictura/test/test.jpg")

    @drawloop begin
        image(img; color_mod=Color(0.5, 0.5, 1.0))
        if framecount() <= 50
            image(img, 20, 20, 400, 200)
            image(img, 520, 20, 400, 200, blendmode=:add, color_mod=Color(1.0, 1.0, 0.5, 0.7))
            image(img, 20, 270, 400, 200, flip_horizontal=true)
            image(img, 520, 270, 400, 200, src_rect=AxisRect(width(img)/2, height(img)/2, 800, 400))
        elseif 50 < framecount() <= 100
            background(255)
            image(img; blendmode="blend", color_mod=Color(0.8, 1.0, 1.0, 0.3))
            translate(20, 20)
            image(img, 0, 0, 400, 200)
            translate(500, 0)
            image(img, 0, 0, 400, 200, flip_vertical=true, blendmode="mul")
            translate(-500, 250)
            image(img, src_rect=AxisRect(width(img)/2, height(img)/2, 800, 400), dst_rect=AxisRect(0, 0, 400, 200))
            translate(500, 0)
            image(img, 0, 0, 400, 200, src_rect=AxisRect(width(img)/2, height(img)/2, 800, 400), blendmode="mod")
        elseif 100 < framecount() < 150
            translate(width()/2, height()/2)
            θ = framecount() / 100
            rotate(θ)
            nofill()
            strokecolor(255, 0, 0)
            rect(-205, -105, 410, 210)
            image(img, dst_rect=Rect(-200, -100, 400, 200, 0))
        else
            framerate(60)
            translate(width()/2, height()/2)
            θ = framecount() / (40*(sin(framecount()/20)+1.5))
            rotate(θ)
            nofill()
            strokecolor(255, 0, 0)
            rect(-205, -105, 410, 210)
            image(img, src_rect=AxisRect(width(img)/2, height(img)/2, 800, 400), 
                       dst_rect=Rect(-200, -100, 400, 200, 0),
                       blendmode=:add,
                       flip_horizontal=true,
                       flip_vertical=true,
                       color_mod=Color(0.9, 0.2, 0.5, 0.8))
        end
        if framecount() % 10 == 0
            println(framerate())
        end
    end

end

@testset "mouseclicked" begin
    @setup  begin
        size(600, 400)
        background(255)
    end

    function f() # redefine mouseclicked on mouseclick
        @mouseclicked begin
            background(255, 0, 0)
            @mouseclicked begin
                background(0, 255, 0)
                @mouseclicked begin
                    background(0, 0, 255)
                    f()
                end
            end
        end
    end

    f()

    @drawloop begin

    end
end

# using Noise
@testset "methods" begin
    a = 300
    @setup begin
        w = 2*a
        size(600, w - 200)
        println(width())
        background(255)
        framerate(360)
        resizable()
    end
    println("resizable? ", Pictura.resizable())
    @test width() == 600
    @test height() == 400
    loadpixels()
    @test pixels()[1, 1] == Color(255)

    @drawloop begin
        println(framecount(), ", ", a, ", ", framerate())
        if framecount() == 20 noloop() end
    end

    @test 1 == 1
    close_window()

end

@testset "framerate" begin
    rate = 10
    @setup begin
        size(800, 600)
        framerate(rate)
    end

    @drawloop begin
        if rand() < 4/rate
            Pictura.FrameRateManager.info()
            
        end
        println(framecount(), ": ", framerate())
        if framecount() > 4rate
            noloop()
        end
    end
end

# sometimes the texture still blacks out, need to resize again to trigger update, dont know why, only seems to happen when resizing in the right moment somehow, very strange
@testset "images and blur filter" begin

    @setup begin
        size(800, 600)
        resizable()
        framerate(10)
    end


    function subsample(img, interval)
        w, h = width(img), height(img)
        ri = 1:interval:h .|> round .|> Int
        ci = 1:interval:w .|> round .|> Int
        sub_pixels = pixels(img)[ri, ci]
        return Image(sub_pixels)
    end

    sub_sample_interval = 2
    blurer = Pictura.blur_filter(sub_sample_interval)
    blur(img) = blur(Image(width(img), height(img)), img, blurer)
    blur(dst, src, filter) = begin Pictura.apply_filter(dst, src, filter); loadpixels(dst); dst end

    img = Image("C:/Users/damia/.julia/dev/Pictura/test/test.jpg")

    naive_subsample = subsample(img, sub_sample_interval^4)

    proper_subsample = subsample(blur(img             ), sub_sample_interval)
    proper_subsample = subsample(blur(proper_subsample), sub_sample_interval)
    proper_subsample = subsample(blur(proper_subsample), sub_sample_interval)
    proper_subsample = subsample(blur(proper_subsample), sub_sample_interval)

    edge_detector = Pictura.discretize_filter([-1 0 1; -2 0 2; -1 0 1])
    # edge_detector = Pictura.discretize_filter([-1 -1 -1; -1 8 -1; -1 -1 -1])

    println(edge_detector)

    edges = Image(width(proper_subsample), height(proper_subsample))
    # v_edges = Pictura.negative(proper_subsample)
    Pictura.apply_filter(edges, proper_subsample, edge_detector)
    loadpixels(edges)

    
    @drawloop begin

        if framecount()%60 < 30
            image(naive_subsample)
        else
            image(proper_subsample)
        end

        # image(edges)

    end

end

@testset "pixels load in rowmajor" begin
    @setup begin
        size(800, 600)
        for r=1:height()
            pixels()[r, :] .= Color((r-1)/height())
        end
        updatepixels()
        framerate(300)
    end
    @drawloop begin
        f = 15*framecount() + Int(floor(10*rand()))
        r = f ÷ width() % height()
        c = f % width()
        pixels()[r+1, c+1] = Color(255, 0, 0)
        println(framecount(), ": ", framerate())
        updatepixels()
    end
end

@testset "transform" begin
    @setup begin
        size(800, 600)
    end
    dx = 0.0
    dy = 0.0
    slide = height()/2
    morph = 500
    @drawloop begin
        background(255)
        if 0 <= framecount() <= slide
            dx += (width()/height())
            dy += 1
        end
        translate(dx, dy)
        rotate(framecount()/342)
        translate(30*sin(framecount()/180), 50*cos(framecount()/220))
        rotate(framecount()/100)
        if framecount() > morph
            scale(1.5sin(framecount()/180), 0.7cos(framecount()/220))
        end

        fillcolor(0, 40, 200, 160)
        strokecolor(0)
        rect(-150, -75, 200, 100, π/4)
        nofill()
        strokecolor(0, 1.0, 0)
        c = center(Rect(-150, -75, 200, 100, π/4))
        ellipse(c.x, c.y, 100, 50, π/4)

        nostroke()
        fillcolor(255, 0, 0)
        rect(-100, -100, 3, 3)
        rect(-100, 0, 3, 3)
        rect(-100, 100, 3, 3)
        rect(0, -100, 3, 3)
        rect(0, 0, 3, 3)
        rect(0, 100, 3, 3)
        rect(100, -100, 3, 3)
        rect(100, 0, 3, 3)
        rect(100, 100, 3, 3)

        if framecount() % 100 == 0
            println(framerate())
        end
    end

    close_window()
end

@testset "fill" begin
    @setup begin
        size(100, 100)
        fillcolor(35)
        @test fillcolor() == Color(35)
        fillcolor(1.0)
        @test fillcolor() == Color(1.0)
        fillcolor(0, 255, 1)
        @test fillcolor() == Color(0, 255, 1)
        fillcolor(0, 1, 0.0)
        @test fillcolor() == Color(0, 1.0, 0)
        fillcolor(0, 1.0, 0)
        @test fillcolor() == Color(0, 1.0, 0)
        fillcolor(0, 1.0, 0.0)
        @test fillcolor() == Color(0, 1.0, 0)
        fillcolor(0.0, 1, 0)
        @test fillcolor() == Color(0, 1.0, 0)
        fillcolor(0.0, 1, 0.0)
        @test fillcolor() == Color(0, 1.0, 0)
        fillcolor(0.0, 1.0, 0)
        @test fillcolor() == Color(0, 1.0, 0)
        fillcolor(1.0, 1.0, 1.0)
        @test fillcolor() == Color(1.0, 1.0, 1.0)
        fillcolor(0, 1, 2, 3)
        @test fillcolor() == Color(0, 1, 2, 3)
        fillcolor(1, 1, 0, 1.0)
        @test fillcolor() == Color(1.0, 1.0, 0.0, 1.0)
        fillcolor(0, 1, 0.0, 1)
        @test fillcolor() == Color(0.0, 1.0, 0.0, 1.0)
        fillcolor(1, 1, 0.0, 1.0)
        @test fillcolor() == Color(1.0, 1.0, 0.0, 1.0)
        fillcolor(0, 1.0, 0, 1)
        @test fillcolor() == Color(0.0, 1.0, 0.0, 1.0)
        fillcolor(1, 1.0, 0, 1.0)
        @test fillcolor() == Color(1.0, 1.0, 0.0, 1.0)
        fillcolor(0, 1.0, 0.0, 1)
        @test fillcolor() == Color(0.0, 1.0, 0.0, 1.0)
        fillcolor(1, 1.0, 0.0, 1.0)
        @test fillcolor() == Color(1.0, 1.0, 0.0, 1.0)
        fillcolor(0.0, 1, 0, 1)
        @test fillcolor() == Color(0.0, 1.0, 0.0, 1.0)
        fillcolor(1.0, 1, 0, 1.0)
        @test fillcolor() == Color(1.0, 1.0, 0.0, 1.0)
        fillcolor(0.0, 1, 0.0, 1)
        @test fillcolor() == Color(0.0, 1.0, 0.0, 1.0)
        fillcolor(1.0, 1, 0.0, 1.0)
        @test fillcolor() == Color(1.0, 1.0, 0.0, 1.0)
        fillcolor(0.0, 1.0, 0, 1)
        @test fillcolor() == Color(0.0, 1.0, 0.0, 1.0)
        fillcolor(1.0, 1.0, 0, 1.0)
        @test fillcolor() == Color(1.0, 1.0, 0.0, 1.0)
        fillcolor(0.0, 1.0, 0.0, 1)
        @test fillcolor() == Color(0.0, 1.0, 0.0, 1.0)
        fillcolor(1.0, 1.0, 0.0, 1.0)
        @test fillcolor() == Color(1.0, 1.0, 0.0, 1.0)
    end

    close_window()
end

@testset "rotate around center" begin
    @setup begin
        size(600, 400)
        # framerate(4)
    end

    @drawloop begin
        # 
        translate(width()/2, height()/2)
        scale(1, 4)
        rotate(framecount() / 50)
        
        background(framecount() % 255)
        strokecolor(0)
        segment(0, 0, 30, 30)
    end
end

@testset "draw stuff" begin
    @setup begin
        size(600, 400)
        framerate(4)
    end

    @drawloop begin
        rotate(0.2)
        translate(100, 40)
        
        background(230, 230, 255)
        fillcolor(0.865, 0, 0)
        strokecolor(0)
        rect(100, 100, 100, 100)
        strokecolor(0, 0, 255)
        segment(0, 0, 300, 300)
    end
end

@testset "teststdfsd" begin
    @setup begin
        size(600, 400)
        framerate(4)
    end

    @drawloop begin
        Pictura.Transform.print_matrix()
        translate(10, 20)
        Pictura.Transform.print_matrix()
        scale(10, 20)
        Pictura.Transform.print_matrix()
        rotate(0.4)
        Pictura.Transform.print_matrix()
        translate(4, 5)
        Pictura.Transform.print_matrix()
        noloop()
    end
end

@testset "translate-segments" begin
    genome = Vector{String}(undef, 5)
    genome[1] = "F"
    lengs = 200
    d = 0
    apply_rules(c) = c == 'F' ? "FF+[+F-F-FB]-[-F+F+FB]" : "" * c
    function grow(s)
        for i=1:length(s)
            next = s[i]
            if next == 'F'
                translate(0, -lengs)
                strokecolor(0)
                d += 30
                segment(0,0,0,lengs)
            elseif next == '+'
                rotate(+0.35)
            elseif next == '-'
                rotate(-0.35)
            elseif next == '['
                push_matrix()
            elseif next == ']'
                pop_matrix()
            elseif next == 'B'
                nostroke()
                fillcolor(50, 200, 20, 100)
                rect(-lengs/4, -lengs/4, lengs/2, lengs/2)
            end 
        end
    end
    @setup begin
        size(1200, 1200)
        for i=2:5
            genome[i] = prod([apply_rules(genome[i-1][j]) for j=1:length(genome[i-1])])
            println(genome[i])
        end
        framerate(0.5)
    end

    iter = 1
    @drawloop begin
        println(iter)
        background(255)
        translate(width() / 3, height())
        grow(genome[iter])
        lengs *= 0.5
        iter += 1
        if iter == 6
            noloop()
            
        end
    end
    sleep(3)
    close_window()
end

function f()
    @setup begin
        size(800, 600)
    end
    @drawloop begin
        if framecount() == 200
            close_window()
        end
    end
end

@testset "allocations1" begin
    @time f()
end

function f2()
    @setup begin
        size(800, 600)
        for r=1:height()
            pixels()[r, :] .= Color((r-1)/height())
        end
        updatepixels()
    end
    @drawloop begin
        for r=1:height()
            pixels()[r, :] .= Color((r-1)/height())
        end
        f = 15*framecount() + Int(floor(10*rand()))
        r = f ÷ width() % height()
        c = f % width()
        pixels()[r+1, c+1] = Color(255, 0, 0)
        updatepixels()
        if framecount() == 200
            close_window()
        end
    end
end

@testset "allocations2" begin
    @time f2()
end

@testset "load and update pixels" begin

    @setup begin
        size(1200, 800)
        resizable()
        pixels()[1, 1] = Color(0)
        background(255)
    end

    @drawloop begin
        loadpixels()
        @test pixels()[1, 1] == Color(255)
        background(200)
        loadpixels()
        @test pixels()[1, 1] == Color(200)
        pixels()[1, 1] = Color(150)
        updatepixels()
        loadpixels()
        @test pixels()[1, 1] == Color(150)
        noloop()
        # @btime loadpixels()
        # @btime updatepixels()
    end
end

@testset "Pictura.jl" begin
    @setup begin
        size(1200, 800)
        resizable()
        background(255)
    end

    @drawloop begin
        background(0,0,0,25)
        loadpixels()
        for i = 1:4000
            w::Int = floor(rand()*width()) + 1
            h::Int = floor(rand()*height()) + 1
            pixels()[h, w] = hsv(w/width(), h/height(), 1)
        end
        updatepixels()
        
    end
end

@testset "hsv" begin
    @setup begin
        size(1200, 800)
        background(255)
    end

    @drawloop begin
        for r=1:height()
            for c=1:width()
                pixels()[r, c] = hsv(((r+c)%400)/400, r/height(), c/width())
            end
        end
        updatepixels()
        noloop()
    end
    sleep(10)
    close_window()
end

@testset "color math" begin
    a = Color(12, 123, 234)
    b = Color(25, 156, 212)
    c = Color(0, 0, 255)
    d = Color(0, 255, 255)
    e = Color(10, 127, 245)
    @test a*(b/a) == b
    @test b*(c/b) == c
    @test c*(d/c) == d
    @test d*(c/d) == c
    @test e*(d/e) == d
    @test d*(e/d) == e
    @test e*(c/e) == c
end

@testset "dvd" begin
    f() = begin
        @setup begin
            size(600, 400)
            resizable()
            framerate(50)
            # borderless()
            fillcolor(hsv(rand(), 1, 1))
            # strokecolor(255)
        end

        x, y = width()/2, height()/2
        dx, dy = 5, 5

        @time begin
            @loop begin
                strokecolor(sin(frameID()/5.0)*0.25 + 0.75)
                background(0)
                x += dx
                y += dy
                if x < 1 || x+40 > width()
                    dx = -dx
                    x += dx
                    fillcolor(hsv(rand(), 1, 1))
                end
                if y < 1 || y+40 > height()
                    dy = -dy
                    y += dy
                    fillcolor(hsv(rand(), 1, 1))
                end
                Pictura.render_rect(x, y, 40, 40)
                if frameID() == 400
                    noloop()
                end
            end
            close_window()
        end
    end # f()

    f()
end

function f()
    @setup begin
        resizable()
        size(800, 600)
    end
    mx = 0
    @loop begin

        for r=1:height(), c=1:width()
            # p = perlin_noise(r/100, c/100, frameID()/30) #, frameID()/30)

            p = voronoi_noise(r/150, c/150, frameID()/40)
            # p = perlin_noise(r/80 -50, c/80 -50, sin(frameID()/15), cos(frameID()/15))

            if p > mx
                println(p)
                mx = p
            end

            pixels()[c, r] = Color(1.2p - 0.1)
        end
        println(framerate())
        # noloop()
        updatepixels()
    end
    close_window()
    println(mx)
end


@testset "noise" begin
    f()
end

@testset "aaline" begin
    @setup begin
        resizable()
        size(800, 600)
        strokecolor(0)
        strokewidth(4)
        # fillcolor(0)
    end

    r = 300
    s = 100

    @loop begin
        background(255)

        # line(400, 300, Pictura.mouse_x(), Pictura.mouse_y())
        Pictura.aa_fill_circle(Pictura.mouse_x(), Pictura.mouse_y(), 30)
    end
end

@testset "text" begin
    try
        @setup begin
            resizable()
            size(800, 600)
            strokecolor(0)
            strokewidth(4)
            framerate(1000)
            textsize(25)
            # fillcolor(0)
        end

        r = 300
        s = 100

        @loop begin
            background(255)
            fillcolor(2)
            text("Hello, World :) ∅, привет уважаемые госпожа", 0, 0)
            if frameID() % 10 == 0 println(framerate()) end
        end
    catch e
        close_window()
        error(e)
    end
end