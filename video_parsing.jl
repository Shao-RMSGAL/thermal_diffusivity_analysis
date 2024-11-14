using CSV
using DataFrames
using Unitful
using Plots
using Interpolations
using Statistics

function parse_thermal_video(file_path)
    # Read the entire file
    data = readlines(file_path)

    # Extract auxiliary data
    aux_data = Dict{String,Any}()
    for i = 1:14
        parts = split(data[i], ',', limit = 3)
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
                parsed_line = parse.(Float64, split_line[2:(end - 1)])
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

    # Apply calibration
    T = [25, 100, 200, 300, 400, 500]
    IR = [24.82, 74.66, 142.73, 217.38, 294.7, 364.8]
    calib = linear_interpolation(IR, T, extrapolation_bc = Line())

    for i = 1:size(frame_data, 1)
        frame_data[i] = calib.(frame_data[i]) .+ 273.15
    end

    return aux_data, frame_data
end
