using Plots
using Plots.PlotMeasures
using SavitzkyGolay
using FiniteDifferences
using Interpolations
using Statistics
using DataFrames

include("structs.jl")

"""
    round_to_odd(num::Real)
Round the provided value to an odd number.
"""
function round_to_odd(num::Real)
    num = round(Int64, num)
    return (num % 2 == 0) ? num + 1 : num
end

"""
    function diffusivitycalculation(
        diffusivitydata::DataFrame,
        options::Options,
    )
Calculate thermal diffusivity using provided diffusivity data.
"""
function diffusivitycalculation(diffusivitydata::DataFrame, options:Options)
    @info "Starting diffusivity calculation..."
    tempmatrixbyframe = diffusivitydata[!, "Interpolated Temperature Matrix"]
    maxes = diffusivitydata[!, "Maximum Temperatures"]
    radiibyframe = diffusivitydata[!, "Radii"]
    radialtempbyframe = diffusivitydata[!, "Average Radial Temperatures"]
    scaledistance = options.scaledistance
    framerate = options.framerate
    framecount = length(maxes)
    framesize = size(tempmatrixbyframe[1])

    window = round_to_odd(length(maxes) / 1000)
    filtered_1d = savitzky_golay(maxes, window, 2, deriv = 1)
    filtered_2d = savitzky_golay(maxes, window, 3, deriv = 2)

    x = range(1, maxes)
    dropoffindex = ceil(Int64, (argmax(maxes) + argmin(filtered_1d.y)) / 2)

    @info "Dropoff at frame $dropoffindex"

    mintemp = 0
    maxtemp = 10
    frame = dropoffindex
    thresholdtemp = 1.0
    while minetmp - maxtemp > thresholdtemp
        mintemp = minimum(radialtempbyframe[frame])
        maxtemp = maximum(radialtempbyframe[frame])
        frame += 1
    end
    frames = frame - dropoffindex
    @info "Zone of interest from frame $dropoffindex-$frame, total $frame frames or $frame/framerate s"

    dudtbyframe = Vector{Vector{Float64}}(undef, frames)
    params = round_to_odd(options.slices/2)
    for i in 1:frames
        frameidx = i + dropoffindex
        dudtbyframe[i] =  savitzky_golay(radialtempbyframe[i], params, 2, deriv = 1).y * framerate
    end

    du2_dr = Vector{Vector{Float64}}(undef, slices)
    for i = 1:frames
        frameidx = i + dropoffindex
        params = length(T_l)
        if params % 2 == 0
            params += 1
        end
        first_deriv = savitzky_golay(T_l, params, 2, deriv = 1).y ./ (r_l[2] - r_l[1])
        second_deriv = savitzky_golay(T_l, params, 3, deriv = 2).y ./ (r_l[2] - r_l[1])^2
        laplace = second_deriv .+ (1.0 ./ r_l) .* first_deriv
        push!(du2_dr, laplace)

    end

    α = zeros(Union{Missing,Float64}, length(du2_dr), length(du_dt))

    for (frame_idx, lap) in enumerate(du2_dr)
        for (rad_idx, val) in enumerate(lap)
            dT = du_dt[rad_idx][frame_idx]
            ΔT = lap[rad_idx]

            if abs(dT) > 1 && abs(ΔT) > 5e-6
                α[frame_idx, rad_idx] = dT / ΔT
            else
                α[frame_idx, rad_idx] = missing
            end

        end
    end

    println("Mean Thermal Diffusivity: $(mean(skipmissing(α))/1000^2) mm²/s")
    println(
        "Standard deviation of Thermal Diffusivity: $(std(skipmissing(α))/1000^2) mm²/s",
    )

    #  if animate
    #      xlimits = (minimum(ri), maximum(ri))
    #      ylimits = (minimum(Ti) - 5, maximum(maxes) + 5)
    #      anim = @animate for i ∈ 1:frames
    #          index = dropoffindex + i
    #          r = collect(keys(T_data[index]))
    #          T = collect(values(T_data[index]))
    #          l = @layout [
    #              a{0.4w} b{0.6w}
    #          ]

    #  sctr_plt = scatter(
    #      plt_anim,
    #      r,
    #      T,
    #      xlim = xlimits,
    #      ylim = ylimits,
    #      xlabel = "Radial distance (μm)",
    #      ylabel = "Temperature (K)",
    #      label = "Data",
    #      legend = :topright,
    #  )
    #  twin_sctr = twinx(sctr_plt)
    #  plot!(
    #      twin_sctr,
    #      r,
    #      du2_dr[i + 1],
    #      label = "Δ(T)",
    #      legend = :right,
    #      ylim = (minimum(du2_dr[1]), maximum(du2_dr[1]) * 100),
    #  )
    #  surf =  surface(
    #          xgrid,
    #          ygrid,
    #          Mat[index],
    #          xlabel = "x-position (μm)",
    #          ylabel = "y-position (μm)",
    #          zlabel = "Temperature (K)",
    #          zlims = ylimits,
    #          clims = ylimits,
    #      )
    #  plot(
    #      sctr_plt,
    #      surf,
    #      size = (1920, 1080),
    #      title = "Animation of temperature over time (frame $index)",
    #      layout = l,
    #  )
    #  end
    #  gif(anim, "./output/flattening.gif", fps = 15)

    #  ylimits = (minimum(T_by_rad[end]), maximum(filter(!isnan, T_by_rad[1])))
    #  circ_limits = (-maximum(radii), maximum(radii))

    #  min = maximum(du_dt[1])
    #  max = minimum(du_dt[1])
    #  for val in du_dt
    #      if minimum(val) < min
    #          min = minimum(val)
    #      end
    #      if maximum(val) > max
    #          max = maximum(val)
    #      end
    #  end

    #  diff_y_lim = (min, max)
    #  anim = @animate for (T_vec, dT, r) ∈ zip(T_by_rad, du_dt, radii)
    #      graph = plot(
    #          #  1:length(T_vec) ./ frame_rate,
    #          T_vec,
    #          title = "Temperature vs. time",
    #          label = "Data",
    #          xlabel = "Time (frame)",
    #          ylabel = "Temperature (K)",
    #          legend = :topright,
    #      )
    #      ylims!(graph, ylimits)

    #      θ = range(0, 2π, length = rad_slices)
    #      x = r .* cos.(θ)
    #      y = r .* sin.(θ)

    #      circ = plot(
    #          x,
    #          y,
    #          title = "Radial position ($(round(r, sigdigits = 5)) μm)",
    #          xlabel = "x distance from center (μm)",
    #          ylabel = "y distance from center (μm)",
    #          label = "Radial position",
    #          aspect_ratio = :equal,
    #          legend = (true, :right),
    #      )
    #      scatter!(circ, [0], [0], label = "hotspot")
    #      xlims!(circ, circ_limits)
    #      ylims!(circ, circ_limits)

    #      diff_twin = twinx(graph)
    #      diff = plot!(
    #          diff_twin,
    #          #  1:length(T_vec) ./ frame_rate,
    #          dT,
    #          label = "Derivative",
    #          color = :red,
    #          ylabel = "Temperature derivative (K/s)",
    #          legend = :right,
    #      )
    #      ylims!(diff_twin, diff_y_lim)

    #      p1 = plot(graph, circ, size = (1920, 1080), margin = 20mm)
    #  end
    #  gif(anim, "./output/radial_T_vs_time.gif", fps = 15)
    #  end

    #  if plotting
    #      println("Starting")
    #      default(
    #  xlim=(1000,1150),
    #  ylim=(400,405),
    #      size = (800, 600),
    #  )
    #  p1 = scatter(x, maxes, label = "data", markersize = 2, color = :black)
    #  p1_twin = twinx(p1)
    #  plot!(
    #      p1,
    #      x,
    #      savitzky_golay(maxes, 21, 1).y,
    #      label = "smoothed curve",
    #      xlabel = "Frame",
    #      ylabel = "Temperature",
    #      color = :orange,
    #  )
    #  plot!(p1_twin, x, filtered_1d.y, label = "first derivative", ylabel = "dT")
    #  plot!(p1_twin, x, filtered_2d.y, label = "second derivative", ylabel = "d²T")
    #  vline!(
    #      p1_twin,
    #      x,
    #      [dropoffindex],
    #      label = "Dropoff",
    #      legend = :bottomright,
    #      style = :dash,
    #  )

    #  r = collect(keys(T_data[dropoffindex])) # radius in μm
    #  T = collect(values(T_data[dropoffindex])) # radius in K

    #  p2 = scatter(ri, Ti, xlabel = "Radius", ylabel = "Temperature (K)", label = "data")
    #  plot!(r, savitzky_golay(T, 5, 2).y, label = "smoothed")

    #  savefig(p1, "./output/drop_off_location.png")
    #  println("Done")
    #  savefig(p2, "./output/drop_off_distribution.png")
    #  end

    return α
end
