
function loadpixels(img::Image)
    pix_before = img.pixel_ptr
    load_pixels(img) 
    pix_after = img.pixel_ptr

    if pix_before != pix_after
        img.pixel_array = unsafe_wrap(Array, Ptr{Color}(img.pixel_ptr), (img.w, img.h))
    end

    @assert img.pixel_array |> !isnothing
end

function updatepixels(img::Image)
    update_pixels(img)
end

Base.transpose(c::Color) = c
 
function pixels(img::Image)
    if img.pixel_ptr |> isnothing
        loadpixels(img)
    end

    return transpose(img.pixel_array)
end

width(img::Image) = img.w
height(img::Image) = img.h