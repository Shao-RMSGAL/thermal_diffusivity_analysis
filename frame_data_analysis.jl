include("structs.jl")

using Statistics

"""
    function extractradialtemp!(
        radialtemps::Vector{Union{Float64, Missing}},
        matrix::Matrix{Float64},
        center::Tuple{Int64, Int64},
        framesize::Tuple{Int64, Int64},
        options::Options,
        )

Extract the average temperature at different radial distances.
"""
function extractradialtemp!(
    radialtemps::SubArray,
    matrix::Matrix{Float64},
    center::Tuple{Int64,Int64},
    framesize::Tuple{Int64,Int64},
    options::Options,
)
    matrixsize = size(matrix)
    radialslices = options.radialslices
    radii =
        range(options.minradius, framesize[argmin(framesize)] / 2, length = options.slices)
    values = Vector{Union{Float64,Missing}}(undef, radialslices)
    θ = range(0, 2π, radialslices)
    ring = Vector{Tuple{Int64,Int64}}(undef, radialslices)

    for (i, r) in enumerate(radii)
        @inbounds for (i_t, t) in enumerate(θ)
            ring[i_t] =
                center .+ round.(Int, (r * cos(t), r * sin(t)) .*
                options.interpolationpoints ./ framesize)
        end
        radialtemps[i] = begin
            for (i_r, coord) in enumerate(ring)
                if 0 < coord[1] < matrixsize[1] && 0 < coord[2] < matrixsize[2]
                    values[i_r] = matrix[coord...]
                else
                    values[i_r] = missing
                end
            end
            mean(skipmissing(values))
        end
    end
end
