
logs = cd(@__DIR__) do
    read(open("info.log", "r"), String)
end

creates = [m[1] for m in eachmatch(r"\[\d+?\] create \[(.+?)\]", logs)]
destroys = [m[1] for m in eachmatch(r"\[\d+?\] destroy \[(.+?)\]", logs)]


println("created and not destroyed")
display(setdiff(creates, destroys))

println("destroyed and not created")
display(setdiff(destroys, creates))
