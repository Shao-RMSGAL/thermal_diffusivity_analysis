"""
extractauxdata!(filename::OrderedDict{String, Any}, filedata::Vector{String})

Extract auxillary data from filedata, such as distance or emissivity.
"""
function extractauxdata!(auxdata::OrderedDict{String,Any}, filedata::Vector{String})
    @debug "Parsing auxillary data from:" filedata
    for i = 1:14
        parts = split(filedata[i], ',', limit = 3)
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
            auxdata[key] = value
        end
    end
    @debug "Parsing successful! Data extracted:" auxdata
    nothing
end

"""
extractframedata!(framedata::Vector{Matrix{Float64}}, filedata::Vector{String})

Extract temperature frame data from filedata into framedata.
"""
function extractframedata!(framedata::Vector{Matrix{Float64}}, filedata::Vector{String})
    @debug "Parsing frame data from" filedata
    currentframe = Vector{Vector{Float64}}()
    for line in filedata[15:end]
        if startswith(line, "Frame")
            if !isempty(currentframe)
                push!(framedata, reduce(vcat, transpose.(currentframe)))
                empty!(currentframe)
            else
                push!(currentframe, parse.(Float64, split(line, ',')[2:end]))
            end
        elseif !isempty(strip(line))
            splitline = split(line, ',')
            if splitline[end] == ""
                parsed_line = parse.(Float64, splitline[2:(end - 1)])
                push!(currentframe, parsed_line)
            else
                parsed_line = parse.(Float64, splitline[2:end])
                push!(currentframe, parsed_line)
            end
        end
    end

    # Add the last frame if it exists
    if !isempty(currentframe)
        push!(framedata, reduce(vcat, transpose.(currentframe)))
    end
    @debug "Parsing successful! Data extracted:" framedata
    nothing
end

"""
applycalibration!(framedata::Vector{Matrix{Float64}}, filedata::Vector{String})

Apply a calibration to the frame data to convert from IR data to thermocouple data.

This assumes that both columns in the calibration data is in °C.
"""
function applycalibration!(framedata::Vector{Matrix{Float64}}, calibrationfilename::String)
    @debug "Applying calibration using \"$calibrationfilename\" to" framedata
    df = read(calibrationfilename, DataFrame)
    calib = linear_interpolation(df.IR, df.T, extrapolation_bc = Line())

    for i = 1:size(framedata, 1)
        framedata[i] = calib.(framedata[i])
    end
    @debug "Calibration successful: Modified data" framedata
    nothing
end

"""
    function parsevideo(
        datafilename::String,
        calibrationfilename::String,
    )::Tuple{OrderedDict{String,Any},Vector{Matrix{Float64}}}
        auxdata = OrderedDict{String,Any}()
        framedata = Vector{Matrix{Float64}}()

Extract a vector of 2D matrices contained within filename.

# Examples
```julia-repl
julia> parsevideo("testdata.csv")
```
"""
function parsevideo(
    datafilename::String,
    calibrationfilename::String,
)::Tuple{OrderedDict{String,Any},Vector{Matrix{Float64}}}
    @debug "Parsing video using \"$calibrationfilename\" for file \"$datafilename\"." 
    auxdata = OrderedDict{String,Any}()
    framedata = Vector{Matrix{Float64}}()

    filedata = readlines(datafilename)
    extractauxdata!(auxdata, filedata)
    extractframedata!(framedata, filedata)
    applycalibration!(framedata, calibrationfilename)
    @debug "Video parsing successful!"

    return auxdata, framedata
end
