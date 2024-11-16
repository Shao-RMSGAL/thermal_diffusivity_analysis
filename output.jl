"""
    printauxdata(auxdata, framedata)

Print auxillary data extracted from a file.
"""
function printauxdata(auxdata::OrderedDict{String,Any}, framedata::Vector{Matrix{Float64}})
    @debug "Printing framedata for" auxdata framedata
    propertystring = "\n"
    for (key, value) in auxdata
        propertystring *= "$key: $value\n"
    end
    propertystring *= "Number of frames: $(length(framedata))
Dimensions of first frame: $(size(framedata[1]))"
    @info propertystring
    nothing
end
