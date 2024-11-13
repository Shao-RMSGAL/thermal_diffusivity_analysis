function find_hotspot_center(matrix)

    # pixel_length = 0.25u"mm"

    max_value = maximum(matrix)
    rows, cols = size(matrix)

    max_positions = Tuple{Int,Int}[]

    for i = 1:rows
        for j = 1:cols
            if matrix[i, j] >= max_value - 0.0001 * max_value
                push!(max_positions, (i, j))
            end
        end
    end

    if isempty(max_positions)
        error("No maximum found. This should not happen with a non-empty matrix.")
    end

    total_x = sum(pos[2] for pos in max_positions)
    total_y = sum(pos[1] for pos in max_positions)
    count = length(max_positions)

    avg_x = total_x / count
    avg_y = total_y / count

    return (round(Int, avg_x), round(Int, avg_y))
end
