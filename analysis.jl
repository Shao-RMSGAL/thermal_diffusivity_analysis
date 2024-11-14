using Plots
using DataFrames
using OrderedCollections

include("video_parsing.jl")
include("find_hotspot_center.jl")
include("output.jl")

function extract_circle_average_temp(
    matrix,
    slices,
    x,
    y,
    scale_dist,
    rad_slices,
    frame_size,
)
    mat_size = size(matrix)
    x = x * frame_size[1] / mat_size[1]
    y = y * frame_size[2] / mat_size[2]
    radii = range(.1, minimum(frame_size) / 2, length = slices) # It was slices - 1, not sure why

     T̅ = OrderedDict{Float64,Float64}()
    θ = range(0, 2π, rad_slices)
    for r in radii
        x₁ = round.(Int, (x .+ r * cos.(θ)) .* mat_size[1] ./ frame_size[1])
        y₁ = round.(Int, (y .+ r * sin.(θ)) .* mat_size[1] ./ frame_size[1])
         T̅[r * scale_dist] = begin
            values = Float64[]
            for (i, j) in zip(x₁, y₁)
                if 0 < i < size(matrix, 1) && 0 < j < size(matrix, 2)
                        push!(values, matrix[i, j])
                end
            end
            mean(values)
        end
    end
     return T̅
end

# Define the run_analysis function (replace with your actual analysis logic)
function run_analysis(
    file_path,
    start_frame,
    end_frame,
    dims,
    scale_dist,
    slices,
    rad_slices,
    do_graphing,
)
    println("Running analysis on file: $file_path")
    aux_data, frame_data = parse_thermal_video(file_path)
    if start_frame == 0
        start_frame = 1
    end
    if end_frame == 0
        end_frame = size(frame_data, 1)
    end

    print_aux_data(aux_data, frame_data)

    x_range = range(0, size(frame_data[1], 1) * scale_dist, dims[1])
    y_range = range(0, size(frame_data[1], 2) * scale_dist, dims[2])

    Mat = Vector{Matrix}()
    average_radial_temperatures =
        [OrderedDict{Float64,Float64}() for _ = 1:(end_frame - start_frame + 1)]
    maxes = zeros(end_frame - start_frame + 1)


    for idx = start_frame:end_frame
        matrix = interpolate_data(frame_data[idx], dims)
        (x, y) = find_hotspot_center(matrix)

        maxes[idx - start_frame + 1] = matrix[x, y]
        average_radial_temperatures[idx - start_frame + 1] = extract_circle_average_temp(
            matrix,
            slices,
            x,
            y,
            scale_dist,
            rad_slices,
            size(frame_data[1]),
        )

        # ϕ = 22.5u"°"
        frac = 0.5
        r = round(Int, frac * minimum(dims) / 2)
        θ = range(0, 2π, length = 100)
        x₁ = round.(Int, x .+ r * cos.(θ))
        y₁ = round.(Int, y .+ r * sin.(θ))
        circ_data = [maximum(matrix) for _ in θ]
        push!(Mat, matrix)

        if do_graphing
            p1 = surface(
                x_range,
                y_range,
                matrix,
                levels = 20,
                fill = true,
                aspect_ratio = :equal,
                legend = :topleft,
                xlabel = "x (μm)",
                ylabel = "y (μm)",
                zlabel = "Temp (K)",
                title = "Temperature of Frame $idx",
                xlims = (minimum(x_range), maximum(x_range)),
                ylims = (minimum(y_range), maximum(y_range)),
            )
            scatter!(
                p1,
                [x_range[x]],
                [y_range[y]],
                [matrix[x, y]],
                label = "Max: $(round(matrix[x, y], sigdigits = 4)) K",
            )
            plot!(
                p1,
                x_range[CartesianIndex.(x₁)],
                y_range[CartesianIndex.(y₁)],
                circ_data,
                label = "Circle",
                width = 10,
            )
            savefig("./output/heat_map/heat_map_$idx.png")
        end
    end
    return average_radial_temperatures, maxes, Mat, size(frame_data[1])
end

