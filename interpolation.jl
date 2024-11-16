using Interpolations

function interpolatedata!(matrix::Matrix{Float64}, framedata::Matrix{Float64}, dims::Tuple{Int64, Int64})
    itp = interpolate(framedata, BSpline(Quadratic(Line(OnGrid()))))
    framesize = size(framedata)
    xrange = range(1, framesize[1], length = dims[1])
    yrange = range(1, framesize[2], length = dims[2])

    matrix .= [itp(x, y) for x in xrange, y in yrange]
    nothing
end
