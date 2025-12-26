
function get_functions(s)
    collect(eachmatch(r"pub export fn (?<name>.*?)\((?<args>[^\{]*)\) (?<return_type>.*?) \{", s))
end

function get_constants(s)
    collect(eachmatch(r"const (?<name>[A-Z]*?) = (?<value>\d*?);", s))
end

function translate_constant(c)
    return "#define $(c[:name]) $(c[:value]);\n"
end

is_function_type(arg) = !isnothing(match(r"\*const fn", arg))


function translate_type(s)
    return if s == "u32"
        "uint32_t"
    elseif s == "i32"
        "int32_t"
    elseif s == "[*:0]const u8"
        "const char*"
    elseif s == "*const anyopaque"
        "void*"
    elseif s == "?*const anyopaque"
        "void*"
    elseif s == "*anyopaque"
        "void*"
    elseif s == "void"
        "void"
    elseif s == "callconv(.c) void"
        "void"
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

function translate_args(s)
    args = collect(eachmatch(r"(?<name>\w+): (?<type>[^,\(]+(\([^\(\)]*\))?[^,]+)", s))
    out = ""
    i = 0
    for a in args 
        if i >= 1
            out *= ", "
        end
        if is_function_type(a.match)
            out *= translate_function_type_arg(a.match)
        else
            out *= "$(translate_type(a[:type])) $(a[:name])"
        end
        i += 1
    end
    out
end

function translate_function_type_arg(s)
    m = match(r"(?<name>\w+): \*const fn \((?<args>.*?)\) (?<return_type>.+)", s)
    return "$(translate_type(m[:return_type])) (*$(m[:name]))($(translate_args(m[:args])))"

end


function translate_function(f)
    return "$(translate_type(f[:return_type])) $(f[:name])($(translate_args(f[:args])));\n"
end

function main()
    in = open("src/exports.zig", "r")
    sin = read(in, String)
    close(in)

    functions = get_functions(sin)

    in = open("src/events.zig", "r")
    sin = read(in, String)
    close(in)
    
    constants = get_constants(sin)
    

    out = open("zig-out/lib/pictura.h", "w")
    write(out, "#ifndef PICTURALIBH\n#define PICTURALIBH\n\n")
    write(out, "#include <inttypes.h>\n\n")

    for c in constants
        write(out, translate_constant(c))
    end

    write(out, "\n")

    for f in functions
        write(out, translate_function(f))
    end

    write(out, "\n#endif")
    close(out)
    
end

main()