using Plots
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
)
    filtered_1d = savitzky_golay(maxes, 51, 2, deriv = 1)
    filtered_2d = savitzky_golay(maxes, 61, 3, deriv = 2)

    x = range(1, length(maxes))

    dropoff_idx = ceil(Int64, (argmax(maxes) + argmin(filtered_1d.y)) / 2)

    println("Dropoff: $dropoff_idx")

    x_grid = range(0, frame_size[1] * scale_dist, length = size(Mat[1], 1))
    y_grid = range(0, frame_size[2] * scale_dist, length = size(Mat[1], 2))
    ri = collect(keys(T_data[dropoff_idx])) # radius in μm
    Ti = collect(values(T_data[dropoff_idx])) # radius in K
    plt_anim = plot()
    frames = 35 # number of frames to view
    t_min = 0
    t_max = 10
    frames = 0
    while t_max - t_min > 0.1
        T = collect(values(T_data[dropoff_idx + frames])) # radius in K
        t_min = minimum(T)
        t_max = maximum(T)
        frames += 1
    end
    println("Frame count: $frames")
    du_dt = filtered_1d.y[dropoff_idx:dropoff_idx  + frames] * frame_rate
    du2_dx = [
        (1 ./r[3:end]) .* diff(r[2:end] .* diff(T) ./ diff(r)) for (r, T) in zip(
            collect.(keys.(T_data[dropoff_idx:dropoff_idx + frames])),
            collect.(values.(T_data[dropoff_idx:dropoff_idx + frames])),
        )
    ]

    α = zeros(length(du_dt), maximum(length.(du2_dx)))
    println(length(du2_dx))
    println(length(du_dt))

    for (t, t_val) in enumerate(du_dt) 
        for (x, x_val) in enumerate(du2_dx[t]) 
            α[t, x] = t_val / x_val
        end
    end

    p3 = surface(α)
    println("Average: $(mean(α)) μm²/ (K⋅s)")
    println("Std. Dev: $(std(α)) μm²/ (K⋅s)")
    savefig(p3, "./output/diffusivity.png")


        
    if false # animate
        xlimits = (minimum(ri), maximum(ri))
        ylimits = (minimum(Ti) - 5, maximum(maxes) + 2)
        anim = @animate for i ∈ 0:frames
            index = dropoff_idx + i
            r = collect(keys(T_data[index]))
            T = collect(values(T_data[index]))
            plot(
                plot(
                    plt_anim,
                    r,
                    T,
                    xlim = xlimits,
                    ylim = ylimits,
                    xlabel = "Radial distance (μm)",
                    ylabel = "Temperature (K)",
                    legend = false,
                ),
                surface(
                    x_grid,
                    y_grid,
                    Mat[index],
                    xlabel = "x-position (μm)",
                    ylabel = "y-position (μm)",
                    zlabel = "Temperature (K)",
                    zlims = ylimits,
                ),
                size = (1920, 1080),
                title = "Animation of temperature over time (frame $index)",
            )
        end
        mp4(anim, "./output/flattening.mp4", fps = 24)
    end

    if plotting
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
        plot!(p1_twin, x, filtered_1d.y, label = "first derivative", ylabel = "dT")
        #  plot!(p1_twin, x, filtered_2d.y, label = "second derivative", ylabel = "d²T")
        vline!(
            p1_twin,
            x,
            [dropoff_idx],
            label = "Dropoff",
            legend = :bottomright,
            style = :dash,
        )

        r = collect(keys(T_data[dropoff_idx])) # radius in μm
        T = collect(values(T_data[dropoff_idx])) # radius in K

        p2 = scatter(ri, Ti, xlabel = "Radius", ylabel = "Temperature (K)", label = "data")
        plot!(r, savitzky_golay(T, 5, 2).y, label = "smoothed")

        savefig(p1, "./output/drop_off_location.png")
        savefig(p2, "./output/drop_off_distribution.png")
    end
end
