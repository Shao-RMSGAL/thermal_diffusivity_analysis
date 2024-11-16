function modvec!(data)
    data[2] = "New info" 
    nothing
end

write("my_file.txt", "JuliaLang is a GitHub organization.\nIt has many members.\n");
data = readlines("my_file.txt")
println(typeof(data))
for entry in data
    println(entry)
end
modvec!(data)
println()
for entry in data
    println(entry)
end

rm("my_file.txt")
