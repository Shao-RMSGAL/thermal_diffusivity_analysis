using Interpolations

"""
    function interpolatedata!(matrix::AbstractArray, framedata::Matrix{Float64}, dims::Tuple{Int64, Int64})

Produce a linearly-interpolated matrix of temperature data.
"""
function interpolatedata!(matrix::AbstractArray, framedata::Matrix{Float64}, dims::Tuple{Int64, Int64})
    itp = interpolate(framedata, BSpline(Quadratic(Line(OnGrid()))))
    framesize = size(framedata)
    xrange = range(1, framesize[1], length = dims[1])
    yrange = range(1, framesize[2], length = dims[2])

    matrix[:,:] .= [itp(x, y) for x in xrange, y in yrange]
    nothing
end
