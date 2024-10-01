using CSV
using DataFrames
using Unitful
using Plots

function parse_thermal_video(file_path)
    # Read the entire file
    data = readlines(file_path)
   
    # Extract auxiliary data
    aux_data = Dict{String, Any}()
    for i in 1:14
        parts = split(data[i], ',', limit=3)
        if length(parts) == 3
            key = strip(parts[2], ':')
            value = strip(parts[3])
            if occursin("°C", value)
                value = parse(Float64, split(value)[1]) * u"°C"
            elseif occursin("%", value)
                value = parse(Float64, split(value)[1]) * u"percent"
            elseif occursin("m", value)
                value = parse(Float64, split(value)[1]) * u"m"
            else
                value = try
                    parse(Float64, value)
                catch
                    value
                end
            end
            aux_data[key] = value
        end
    end

    # Extract frame data
    frame_data = Vector{Matrix{Float64}}()
    current_frame = Vector{Vector{Float64}}()
    
    for line in data[15:end]
        if startswith(line, "Frame")
            if !isempty(current_frame)
                push!(frame_data, reduce(vcat, transpose.(current_frame)))
                current_frame = Vector{Vector{Float64}}()
            else
                push!(current_frame, parse.(Float64, split(line, ',')[2:end]))
            end
        elseif !isempty(strip(line))
            split_line = split(line, ',')
            if split_line[end] == ""
                parsed_line = parse.(Float64, split_line[2:end - 1])
                push!(current_frame, parsed_line)
            else
                parsed_line = parse.(Float64, split_line[2:end])
                push!(current_frame, parsed_line)
            end
        end
    end
    
    # Add the last frame if it exists
    if !isempty(current_frame)
        push!(frame_data, reduce(vcat, transpose.(current_frame)))
    end

    return aux_data, frame_data
end

function find_hotspot_center(matrix)
    max_value = maximum(matrix)
    rows, cols = size(matrix)
    
    max_positions = Tuple{Int, Int}[]
    
    for i in 1:rows
        for j in 1:cols
            if matrix[i, j] == max_value
                push!(max_positions, (i, j))
            end
        end
    end
    
    if isempty(max_positions)
        error("No maximum found. This should not happen with a non-empty matrix.")
    end
    
    total_x = sum(pos[2] for pos in max_positions)
    total_y = sum(pos[1] for pos in max_positions)
    count = length(max_positions)
    
    avg_x = total_x / count
    avg_y = total_y / count
    
    return (avg_x, avg_y)
end

# Usage
file_path = "./Sample2_Extracted Data/Sample2 RT M1.csv"
aux_data, frame_data = parse_thermal_video(file_path)

for (idx,_) in enumerate(frame_data)
    frame_data[idx] .+= 273.15
end

# Print auxiliary data
for (key, value) in aux_data
    println("$key: $value")
end

# Print information about frame data
println("Number of frames: $(length(frame_data))")
println("Dimensions of first frame: $(size(frame_data[1]))")

gr()

idx = 750
p1 = contour(frame_data[idx], levels = 20, fill=true)
(x,y) = find_hotspot_center(frame_data[idx])
println("$x, $y")
scatter!(p1, [x], [y])

gui()
