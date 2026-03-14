using Pkg.Artifacts
using Tar, Inflate, SHA
using Base.BinaryPlatforms
using CodecZlib

# Configuration
toml_path = joinpath(@__DIR__, "Artifacts.toml")
files = [
    (arch="x86_64", os="linux", url="https://github.com/Zhurgut/Pictura.jl/releases/download/v0.1.0/picturalib-x86_64-linux.tar.gz"),
    (arch="x86_64", os="windows", url="https://github.com/Zhurgut/Pictura.jl/releases/download/v0.1.0/picturalib-x86_64-windows.tar.gz")
]

for file in files

    println("downloading tarball at ", file.url)
    tarball = download(file.url)

    file_sha = bytes2hex(open(sha256, tarball))

    tree_sha = open(tarball) do io
        Tar.tree_hash(GzipDecompressorStream(io))
    end

    println("writing to Artifacts.toml...")
    bind_artifact!(
        toml_path,
        "picturalib",
        Base.SHA1(tree_sha);
        platform = Platform(file.arch, file.os),
        download_info = [(file.url, file_sha)],
        force = true
    )

end