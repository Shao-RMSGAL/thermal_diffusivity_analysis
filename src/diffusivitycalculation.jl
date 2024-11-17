"""
    round_to_odd(num::Real)
Round the provided value to an odd number.
"""
function round_to_odd(num::Real)
    num = round(Int64, num)
    return (num % 2 == 0) ? num + 1 : num
end
"""
    locatedropoff(diffusivitydata::DataFrame)
Determine the dropoff location.
"""
function locatedropoff(diffusivitydata::DataFrame)
    maxes = diffusivitydata[!, "Maximum Temperatures"]
    radialtempbyframe = diffusivitydata[!, "Average Radial Temperatures"]
    window = round_to_odd(11)
    params = 5
    filtered_1d = savitzky_golay(maxes, window, 2, deriv = 1).y
    filtered = savitzky_golay(maxes, window, params, deriv = 0).y

    dropoffindex = argmin(filtered_1d)

    currenttemp = maxes[dropoffindex]
    prevtemp = maxes[dropoffindex - 1]
    while currenttemp < prevtemp
        currenttemp = filtered[dropoffindex]
        prevtemp = filtered[dropoffindex - 1]
        dropoffindex -= 1
        if dropoffindex == 1
            @warn "Dropoff lookback terminated at beginning frame. Check dataset."
            break
        end
    end
    dropoffindex += 1

    @info "Max frame: $dropoffindex"
    mintemp = 0
    maxtemp = 10
    frame = dropoffindex
    thresholdtemp =
        (maximum(radialtempbyframe[end]) - minimum(radialtempbyframe[end])) * 1.1
    while maxtemp - mintemp > thresholdtemp
        mintemp = minimum(radialtempbyframe[frame])
        maxtemp = maximum(radialtempbyframe[frame])
        frame += 1
        if frame == length(maxes)
            @warn "Reached the end of frame data. Possibly poor threshold minimum
        temperature difference. Consider increasing threshold."
            break
        end
    end
    frames = frame - dropoffindex
    
    if frames < 2
        frames = 10
        @warn "No dropoff detected. Check data."
    end

    return dropoffindex, frames
end

"""
    function diffusivitycalculation(
        diffusivitydata::DataFrame,
        options::Options,
    )
Calculate thermal diffusivity using provided diffusivity data.
"""
function diffusivitycalculation(diffusivitydata::DataFrame, options::Options)
    @info "Starting diffusivity calculation..."
    radiibyframe = diffusivitydata[!, "Radii"][1] # All identical. Take the first.
    radialtempbyframe = diffusivitydata[!, "Average Radial Temperatures"]
    framerate = options.framerate
    slices = options.slices
    radialincrement = Float64(radiibyframe.step)

    dropoffindex, frames = locatedropoff(diffusivitydata)
    @info "Zone of interest from frame $dropoffindex-$frame, total $frames frames or $(frames/framerate) s"
    @info "Calculating time derivative over radius"
    dudtbyradius = SharedArray{Float64,2}((frames, slices))
    tempvstime_over_radius =
        [[radialtempbyframe[i + dropoffindex][j] for i = 1:frames] for j = 1:slices]
    params = round_to_odd(frames)
    for i = 1:slices
        while true
            try
                dudtbyradius[:, i] .=
                    savitzky_golay(tempvstime_over_radius[i], params, 2, deriv = 1).y *
                    framerate
                break
            catch e
                @warn e
                params += 2
                break
            end
        end
    end
    @info "Time derivatives calculated"
    @info "Calculating Laplacian over time"
    laplacian_over_time = SharedArray{Float64,2}(slices, frames)
    for i = 1:frames
        frameidx = i + dropoffindex
        params = round_to_odd(slices / 2)
        firstderiv =
            savitzky_golay(radialtempbyframe[frameidx], params, 2, deriv = 1).y ./
            (radialincrement)
        secondderiv =
            savitzky_golay(radialtempbyframe[frameidx], params, 3, deriv = 2).y ./
            (radialincrement)^2
        @debug sizeof(firstderriv)
        @debug sizeof(secondderriv)
        @debug sizeof(radiibyframe)
        laplacian_over_time[:, i] .= secondderiv .+ (1.0 ./ radiibyframe) .* firstderiv
    end
    @info "Laplacians calculated"
    @info "Calculating thermal diffusivity"
    @info size(dudtbyradius) size(laplacian_over_time)
    α = []
    ᾱ,σα = (0,0)
    try
        α =
            ifelse.(
                (abs.(dudtbyradius') .> 1) .& (abs.(laplacian_over_time) .> 5e-6),
                dudtbyradius' ./ laplacian_over_time,
                missing,
            )
         ᾱ = mean(skipmissing(α)) / 1000^2
        σα = std(skipmissing(α)) / 1000^2
    @info "Thermal diffusivity calculated.
Value: $ᾱ mm²/s
Standard Deviation: $σα mm²/s"
    catch
        ᾱ = 0
        σα = 0
        @warn "Could not calculate diffusivity. Beware of results. Consider adjusting thresholds on time derivative and Laplacian."
    end
    result = DataFrame(diffusivitydata[dropoffindex:(dropoffindex + frames - 1), :])
    result[!, "∇²T"] = [view(laplacian_over_time, :, i) for i = 1:frames]
    result[!, "δT/δt"] = [view(dudtbyradius', :, i) for i = 1:frames]
    result[!, "α"] = [view(α, :, i) for i = 1:frames]
     return result, (ᾱ, σα)
end
