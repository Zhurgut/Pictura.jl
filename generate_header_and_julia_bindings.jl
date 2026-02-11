
#
# functions to parse source files and get names and values that are to be exported
#

function get_constants(file_string)
    cns = collect(eachmatch(r"const (?<name>[A-Z]*?) = (?<value>\d*?);", file_string))
    return [(name=cn[:name], value=cn[:value]) for cn in cns]
end

function get_functions(file_string)
    fns = collect(eachmatch(r"pub export fn (?<name>.*?)\((?<args>[^\{]*)\) (?<return_type>.*?) \{", file_string))
    names = [f[:name] for f in fns]
    raw_args = [f[:args] for f in fns]
    args = [get_args(arg) for arg in raw_args]
    return_types = [f[:return_type] for f in fns]
    
    return [(name=names[i], args=args[i], return_type=return_types[i]) for i=eachindex(fns)]
end

function get_args(args_string)
    args = collect(eachmatch(r"(?<name>\w+): (?<type>[^,\(]+(\([^\(\)]*\))?[^,]+)", args_string))
    args = [(name=arg[:name], type=arg[:type]) for arg in args]
    args = [is_function_type(arg.type) ? (name=arg.name, type="*const fn", fn_arg=get_function_type_arg(arg.type)) : arg for arg in args]
    return args
end

is_function_type(arg) = contains(arg, "*const fn")

function get_function_type_arg(s)
    m = match(r"\*const fn \((?<args>.*?)\) callconv\(.c\) (?<return_type>.+)", s)
    return (type="*const fn", args=get_args(m[:args]), return_type=m[:return_type])

end





#
# functions to translate zig into C for the picturalib.h header
#
function translate_constant(c)
    return "#define $(c.name) $(c.value)\n"
end

function translate_type(s)
    return if s == "u32"
        "uint32_t"
    elseif s == "ErrorCode"
        "uint32_t"
    elseif s == "root.vulkan.PFN_vkVoidFunction"
        "PFN_vkVoidFunction"
    elseif s == "root.vulkan.VkInstance"
        "VkInstance"
    elseif s == "root.vulkan.VkPhysicalDevice"
        "VkPhysicalDevice"
    elseif s == "root.vulkan.VkDevice"
        "VkDevice"
    elseif s == "root.vulkan.VkQueue"
        "VkQueue"
    elseif s == "*root.vulkan.VkCommandBuffer"
        "VkCommandBuffer*"
    elseif s == "i32"
        "int32_t"
    elseif s == "[*:0]const u8"
        "const char*"
    elseif s == "?[*][*:0]const u8"
        "const char**"
    elseif s == "Image"
        "Image"
    elseif s == "?Image"
        "Image"
    elseif s == "void"
        "void"
    elseif s == "?*anyopaque"
        "void*"
    elseif s == "callconv(.c) void"
        "void"
    elseif s == "[*]u32"
        "uint32_t*"
    elseif s == "?[*]u32"
        "uint32_t*"
    elseif s == "bool"
        error("bool not unviersally the same")
    elseif s == "f32"
        "float"
    elseif s == "f64"
        "double"
    elseif s == "u64"
        "uint64_t"
    elseif s == "?*f32"
        "float*"
    elseif s == "?*i32"
        "int32_t*"
    elseif s == "u8"
        "uint8_t"
    elseif s == "*u32"
        "uint32_t*"
    elseif s == "*i32"
        "int32_t*"
    else
        error("$s undefined, cannot translate type")
    end
    
end

function translate_args(args)
    out = ""
    for (i, a) in enumerate(args) 
        if i > 1 out *= ", " end

        if a.type == "*const fn"
            out *= translate_function_type_arg(a.name, a.fn_arg)
        else
            out *= "$(translate_type(a.type)) $(a.name)"
        end
    end
    out
end

function translate_function(f)
    return "$(translate_type(f.return_type)) $(f.name)($(translate_args(f.args)));\n"
end

function translate_function_type_arg(name, arg)
    return "$(translate_type(arg.return_type)) (*$name)($(translate_args(arg.args)))"

end




#
# functions to generate julia bindings
#


function write_c_header(out, constants, functions)
    write(out, "#ifndef PICTURALIBH\n#define PICTURALIBH\n\n")
    write(out, """#include "vulkan/volk.h"\n""")
    write(out, "#include <inttypes.h>\n\n")
    
    for c in constants
        write(out, translate_constant(c))
    end

    write(out, "\n")
    write(out, "typedef void* Image;\n\n")

    for f in functions
        write(out, translate_function(f))
    end

    write(out, "\n#endif")
end

function write_jl_module(out, constants, functions)
    write(out, """
module PicturaLib

using CBinding

c`-std=c99 -I\$(joinpath(@__DIR__, "..", "include")) -L\$(@__DIR__) -lpictura`

c"uint8_t" = UInt8
c"uint16_t" = UInt16
c"uint32_t" = UInt32
c"uint64_t" = UInt64

c"int8_t" = Int8
c"int16_t" = Int16
c"int32_t" = Int32
c"int64_t" = Int64

c"VkResult" = Int32
c"PFN_vkVoidFunction" = Cptr{Cvoid}
c"VkInstance" = Cptr{Cvoid}
c"VkPhysicalDevice" = Cptr{Cvoid}
c"VkDevice" = Cptr{Cvoid}
c"VkQueue" = Cptr{Cvoid}
c"VkCommandBuffer" = Cptr{Cvoid}
# Sys.WORD_SIZE == 64 ? Ptr{Cvoid} : UInt64 # for non-dispatchable handles

c\"\"\"
#include "picturalib.h"
\"\"\"n

""")

    for c in constants
        write(out, "const $(c.name) = $(c.value)\n")
    end

    write(out, "\n")
    
    for f in functions
        if !contains(f.name, "_vk_") && f.name != "init2" 
            write(out, "const $(f.name) = c\"$(f.name)\"[]\n")
        end
    end

    write(out, "\n\nend")

end

function main()
    cd(@__DIR__)
    in = open("src/exports.zig", "r")
    sin = read(in, String)
    close(in)

    functions = get_functions(sin)

    in = open("src/events.zig", "r")
    sin = read(in, String)
    close(in)
    
    constants = get_constants(sin)
    

    c_header = open("zig-out/include/picturalib.h", "w")
    write_c_header(c_header, constants, functions)
    close(c_header)

    jl_module = open("zig-out/lib/picturalib.jl", "w")
    write_jl_module(jl_module, constants, functions)
    close(jl_module)
    
end

main()