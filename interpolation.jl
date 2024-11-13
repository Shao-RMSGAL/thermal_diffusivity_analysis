using Interpolations

function interpolate_data(frame_data, dims)
    itp = interpolate(frame_data, BSpline(Quadratic(Line(OnGrid()))))
    x_range = range(1, size(frame_data, 1), length = dims[1])
    y_range = range(1, size(frame_data, 2), length = dims[2])
    matrix = zeros(dims[1], dims[2])

    for x in eachindex(x_range)
        for y in eachindex(y_range)
            matrix[x, y] = itp(x_range[x], y_range[y])
        end
    end

    return matrix
end
