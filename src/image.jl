

"""
    Image

A struct representing a 2D image buffer.

The `Image` object encapsulates both the pixel data stored in host memory (CPU) 
and the corresponding texture data on the GPU. 

# Constructors

Image(width, height) to create an empty image with specified dimensions
Image(pixels::Matrix{PicturaColor}) to create an image from pixels

# Accessing and Synchronizing Pixels

To manipulate the image data directly on the host side, use [`pixels`](@ref). 

- To push changes from the CPU to the GPU (e.g., after modifying the pixels), 
  call [`updatepixels`](@ref).
- To pull pixel values from the GPU to the CPU, call [`loadpixels`](@ref).
- To query dimensions, use [`width`](@ref) and [`height`](@ref).

# See also
[`pixels`](@ref), [`updatepixels`](@ref), [`loadpixels`](@ref), [`width`](@ref), [`height`](@ref)
"""
mutable struct Image
    w::UInt32
    h::UInt32
    ptr::Ptr{Cvoid}
    pixel_ptr::Union{Ptr{UInt32},Nothing}
    pixel_array::Union{Matrix{PicturaColor},Nothing}
end

Image(w, h, ptr::Ptr{Cvoid}) = Image(w, h, ptr, nothing, nothing)
Image(w, h) = Core.create_image(w, h)
Image(pixels::Matrix{PicturaColor}) = Core.create_image(pixels)




Base.size(img::Image) = (img.h, img.w)

"""
    loadpixels(img::Image)
Synchronize pixel data from the GPU to host memory.

Use this function to pull the current pixel data from the GPU texture 
into a `Matrix{PicturaColor}` that can be read and manipulated in Julia.
"""
function loadpixels(img::Image)

    new_pixels = PicturaLib.load_pixels(img.ptr)
    if new_pixels == C_NULL
        error("failed to load pixels")
    end

    if img.pixel_ptr != new_pixels
        img.pixel_ptr = new_pixels
        img.pixel_array = unsafe_wrap(Array, Ptr{PicturaColor}(new_pixels), (img.w, img.h))
    end

    @assert img.pixel_array |> !isnothing
end





"""
        updatepixels(img::Image)
Synchronize pixel data from host memory to the GPU.

Use this function after modifying the pixel matrix in Julia to upload 
the changes to the GPU texture for rendering.
"""
function updatepixels(img::Image)
    PicturaLib.update_pixels(img.ptr)
end




"""
    pixels(img::Image)
Provide access to pixel data on the host (CPU) side.

# Example Usage
pixels(img)[row, col] = color(1,2,3)

To access pixels of the main drawing window, call
pixels()[row, col]

Pixel data must be synchronized manually between CPU and GPU, 
See [`loadpixels`](@ref), [`updatepixels`](@ref)
"""
function pixels(img::Image)
    if img.pixel_ptr |> isnothing
        loadpixels(img)
    end

    return transpose(img.pixel_array)
end

Base.transpose(c::PicturaColor) = c


"""
width(img::Image)
Return the width of the image in pixels.
"""
width(img::Image) = img.w

"""
height(img::Image)
Return the height of the image in pixels.
"""
height(img::Image) = img.h




