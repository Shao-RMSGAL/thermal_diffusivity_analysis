using Plots
using Plots.PlotMeasures
using SavitzkyGolay
using FiniteDifferences
using Interpolations
using Statistics

function diffusivity_calculation(
    T_data,
    maxes,
    Mat,
    frame_size,
    scale_dist,
    plotting,
    animate,
    frame_rate,
    radii,
    rad_slices,
)
    window = round(Int64, length(maxes) / 100)
    if window % 2 == 0
        window += 1
    end
    filtered_1d = savitzky_golay(maxes, window, 2, deriv = 1)
    filtered_2d = savitzky_golay(maxes, window, 3, deriv = 2)

    x = range(1, length(maxes))

    dropoff_idx = ceil(Int64, (argmax(maxes) + argmin(filtered_1d.y)) / 2)

    println("Dropoff: $dropoff_idx")

    x_grid = range(0, frame_size[1] * scale_dist, length = size(Mat[1], 1))
    y_grid = range(0, frame_size[2] * scale_dist, length = size(Mat[1], 2))
    ri = collect(keys(T_data[dropoff_idx])) # radius in μm
    Ti = collect(values(T_data[dropoff_idx])) # radius in K
    plt_anim = plot()
    t_min = 0
    t_max = 10
    frames = 0
    while t_max - t_min > 1
        T = collect(values(T_data[dropoff_idx + frames])) # radius in K
        t_min = minimum(T)
        t_max = maximum(T)
        frames += 1
    end

    frames = 10

    println("Frame count: $frames")

    T_by_rad = Vector{Vector{Float64}}()
    r = collect(keys(T_data[dropoff_idx]))
    for (idx, _) in enumerate(r)
        push!(T_by_rad, Vector{Float64}())
    end


    for frame = dropoff_idx:(dropoff_idx + frames)
        r = collect(keys(T_data[frame]))
        T = collect(values(T_data[frame]))
        for (rad_idx, _) in enumerate(r)
            push!(T_by_rad[rad_idx], T[rad_idx])
        end
    end

    du_dt = Vector{Vector{Float64}}()
    for T_vec in T_by_rad
        r = collect(keys(T_data[1]))
        params = ceil(Int64, length(T_vec) / 2)
        if params % 2 == 0
            params += 1
        end
        push!(du_dt, savitzky_golay(T_vec, params, 2, deriv = 1).y * frame_rate) # du_dt
    end

    du2_dr = Vector{Vector{Float64}}()

    for i = dropoff_idx:(dropoff_idx + frames)
        r_l = collect(keys(T_data[i]))
        T_l = collect(values(T_data[i]))

        #  println("Frame: $i")
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

    if animate
        println("test 1")
        xlimits = (minimum(ri), maximum(ri))
        ylimits = (minimum(Ti) - 5, maximum(maxes) + 5)
        println("test 2")
        anim = @animate for i ∈ 1:frames
            println("test 3")
            index = dropoff_idx + i
            r = collect(keys(T_data[index]))
            T = collect(values(T_data[index]))
            l = @layout [
                a{0.4w} b{0.6w}
            ]

            println("test 4")
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
            #  println("test 5")
            #  twin_sctr = twinx(sctr_plt)
            #  plot!(
            #      twin_sctr,
            #      r,
            #      du2_dr[i + 1],
            #      label = "Δ(T)",
            #      legend = :right,
            #      ylim = (minimum(du2_dr[1]), maximum(du2_dr[1]) * 100),
            #  )
            surf =  surface(
                    x_grid,
                    y_grid,
                    Mat[index],
                    xlabel = "x-position (μm)",
                    ylabel = "y-position (μm)",
                    zlabel = "Temperature (K)",
                    zlims = ylimits,
                    clims = ylimits,
                ),
            println("test 6")
            #  plot(
            #      sctr_plt,
            #      surf,
            #      size = (1920, 1080),
            #      title = "Animation of temperature over time (frame $index)",
            #      layout = l,
            #  )
        end
        println("test 7")
        gif(anim, "./output/flattening.gif", fps = 15)
        println("test 8")

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
    end

    if plotting
        println("Starting")
        default(
            #  xlim=(1000,1150),
            #  ylim=(400,405),
            size = (800, 600),
        )
        p1 = scatter(x, maxes, label = "data", markersize = 2, color = :black)
        p1_twin = twinx(p1)
        plot!(
            p1,
            x,
            savitzky_golay(maxes, 21, 1).y,
            label = "smoothed curve",
            xlabel = "Frame",
            ylabel = "Temperature",
            color = :orange,
        )
        #  plot!(p1_twin, x, filtered_1d.y, label = "first derivative", ylabel = "dT")
        #  plot!(p1_twin, x, filtered_2d.y, label = "second derivative", ylabel = "d²T")
        vline!(
            p1_twin,
            x,
            [dropoff_idx],
            label = "Dropoff",
            legend = :bottomright,
            style = :dash,
        )

        #  r = collect(keys(T_data[dropoff_idx])) # radius in μm
        #  T = collect(values(T_data[dropoff_idx])) # radius in K

        #  p2 = scatter(ri, Ti, xlabel = "Radius", ylabel = "Temperature (K)", label = "data")
        #  plot!(r, savitzky_golay(T, 5, 2).y, label = "smoothed")

        savefig(p1, "./output/drop_off_location.png")
        println("Done")
        #  savefig(p2, "./output/drop_off_distribution.png")
    end

    return α
end
