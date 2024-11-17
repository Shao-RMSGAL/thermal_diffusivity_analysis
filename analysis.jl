using Plots
using DataFrames
using OrderedCollections
using Distributed
using SharedArrays

include("videoparsing.jl")
include("framedataanalysis.jl")
include("output.jl")
include("structs.jl")

"""
    run_analysis(options::Options)
Run analysis on thermal diffusivity data using provided options.
"""
function run_analysis(options::Options)

    slices = options.slices
    startframe = options.startframe
    endframe = options.endframe

    aux_data, frame_data = parsevideo(options.filename, options.calibrationfilename)
    startframe = (startframe == 0) ? 1 : startframe
    endframe = (endframe == 0) ? size(frame_data, 1) : endframe
    numframes = endframe - startframe + 1
    framesize = size(frame_data[1])

    @info "Running analysis on file \"$(options.filename)\" for frame $startframe to $endframe"
    printauxdata(aux_data, frame_data)

    averageradialtemperatures = Vector{Vector{Union{Float64,Missing}}}(undef, numframes)
    for idx = 1:numframes
        averageradialtemperatures[idx] = Vector{Union{Float64,Missing}}(undef, slices)
    end

    maxes = Vector{Float64}(undef, numframes)

    averageradialtemperatures = SharedArray{Float64,2}((slices, numframes))
    interpmatrix = SharedArray{Float64,3}((options.interpolationpoints..., numframes))
    @info size(interpmatrix)
    maxes = SharedArray{Float64,1}(numframes)

    radii =
        range(
            options.minradius,
            framesize[argmin(framesize)] / 2,
            length = options.slices,
        ) * options.scaledistance

    #  @sync @distributed for (i, idx) in enumerate(startframe:endframe)
    @sync @distributed for i in 1:numframes
        interpolatedata!(
            view(interpmatrix, :, :, i),
            frame_data[i],
            options.interpolationpoints,
        )
        maxes[i], center = findmax(interpmatrix[:, :, i])
        extractradialtemp!(
            view(averageradialtemperatures, :, i),
            interpmatrix[:, :, i],
            convert(Tuple{Int64,Int64}, center),
            framesize,
            options,
        )
    end

    @info "Analysis Complete"

    return DataFrame(
        "Frame" => startframe:endframe,
        "Average Radial Temperatures" => [
            view(averageradialtemperatures, :, i) for
            i in size(averageradialtemperatures, 2)
        ],
        "Maximum Temperatures" => maxes,
        "Interpolated Temperature Matrix" =>
            [view(interpmatrix, :, :, i) for i in size(interpmatrix, 3)],
        "Frame size" => size.(frame_data),
        "Radii" => fill(radii, numframes),
    )
end

