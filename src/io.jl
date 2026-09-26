
import FileIO

"""
    load_image(path)
Load an image from a file into a `Pictura.Image`.

# Arguments
- `path`: The file path to the image.

# Returns
- `Image`: The loaded image object.
"""
function load_image(path)
    @assert app.is_initialized

    img::Matrix{PicturaColor} = FileIO.load(path)
    return Image(img)
end

"""
    save_image(img::Image, path)
Save an `Image` to a file.

# Arguments
- `img::Image`: The image to be saved.
- `path`: The destination file path.
"""
function save_image(img::Image, path)
    @assert app.is_initialized

    out::Matrix{PicturaColors.Colors.RGBA{Float32}} = pixels(img)[:, :]
    FileIO.save(path, out)
end

"""
    save_frame(path)
Save the current frame of the drawing window to a file.

# Arguments
- `path`: The destination file path.
"""
function save_frame(path)
    @assert app.is_initialized
    save_image(app.canvas, path)
end

