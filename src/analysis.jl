"""
    run_analysis(options::Options)
Run analysis on thermal diffusivity data using provided options.
"""
function run_analysis(options::Options)
    @info "Running initial analysis with options" options
    slices = options.slices
    startframe = options.startframe
    endframe = options.endframe

    aux_data, framedata = parsevideo(options.filename, options.calibrationfilename)

    @info "Parsing video data complete:" options.calibrationfilename
    startframe = (startframe == 0) ? 1 : startframe
    endframe = (endframe == 0) ? size(framedata, 1) : endframe
    framedata = framedata[startframe:endframe]
    framecount = endframe - startframe + 1
    framesize = size(framedata[1])

    @info "Running analysis on file \"$(options.filename)\" for frame $startframe to $endframe"
    printauxdata(aux_data, framedata)

    averageradialtemperatures = Vector{Vector{Union{Float64,Missing}}}(undef, framecount)
    for idx = 1:framecount
        averageradialtemperatures[idx] = Vector{Union{Float64,Missing}}(undef, slices)
    end

    maxes = Vector{Float64}(undef, framecount) # TODO: Probably not needed. Test.

    averageradialtemperatures = SharedArray{Float64,2}((slices, framecount))
    averageradialtemperaturesstdev = SharedArray{Float64,2}((slices, framecount))
    interpmatrix = SharedArray{Float64,3}((options.interpolationpoints..., framecount))
    maxes = SharedArray{Float64,1}(framecount)

    radii =
        range(
            options.minradius,
            framesize[argmin(framesize)] / 2,
            length=options.slices,
        ) * options.scaledistance

    centers = Vector{CartesianIndex}() # For storing the center hotspot
    if options.hotspottrackingenabled
        @info "Running with hotspot tracking"
        @sync @distributed for i = 1:framecount
            interpolatedata!(
                view(interpmatrix, :, :, i),
                framedata[i],
                options.interpolationpoints,
            )
            maxes[i], center = findmax(interpmatrix[:, :, i])
            push!(centers, center)
            extractradialtemp!(
                view(averageradialtemperatures, :, i),
                interpmatrix[:, :, i],
                convert(Tuple{Int64,Int64}, center),
                framesize,
                options,
            )
        end
    else # Disable hotspot tracking (HACK)
        @info "Running without hotspot tracking"
        for i = 1:framecount
            interpolatedata!(
                view(interpmatrix, :, :, i),
                framedata[i],
                options.interpolationpoints,
            )
            try
                maxes[i], center = findmax(interpmatrix[:, :, i])
                push!(centers, center)
            catch e
                @warn e
            end
        end


        center = centers[findfirst(x -> x == maximum(maxes), maxes)]
        for i in 1:length(centers) # Hack to ensure all recorded center data is the same
            centers[i] = center
        end
        @info "Fixed center at " center

        @sync @distributed for i = 1:framecount
            extractradialtemp!(
                view(averageradialtemperatures, :, i),
                interpmatrix[:, :, i],
                convert(Tuple{Int64,Int64}, center),
                framesize,
                options,
            )
        end
    end

    @info "Analysis Complete"

    return DataFrame(
        "Frame" => 1:framecount,
        "Average Radial Temperatures" => [
            view(averageradialtemperatures, :, i) for
            i = 1:size(averageradialtemperatures, 2)
        ],
        "Average Radial Temperatures Standard Deviation" => [
            view(averageradialtemperaturesstdev, :, i) for
            i = 1:size(averageradialtemperaturesstdev, 2)
        ],
        "Maximum Temperatures" => maxes,
        "Interpolated Temperature Matrix" =>
            [view(interpmatrix, :, :, i) for i = 1:size(interpmatrix, 3)],
        "Frame size" => size.(framedata),
        "Radii" => fill(radii, framecount),
        "Centers" => centers,
    )
end
