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


    T_by_rad = Vector{Vector{Float64}}()
    r = collect(keys(T_data[dropoff_idx]))
    for (idx, _) in enumerate(r)
        push!(T_by_rad, Vector{Float64}())
    end


    for frame in dropoff_idx:dropoff_idx + frames
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
        
    for i in dropoff_idx:dropoff_idx + frames
        r_l = collect(keys(T_data[i]))
        T_l =  collect(values(T_data[i]))

        #  println("Frame: $i")
        params = length(T_l)
        if params % 2 == 0
            params += 1
        end

        first_deriv = savitzky_golay(T_l, params, 2, deriv = 1).y ./ (r_l[2] - r_l[1])
        second_deriv = savitzky_golay(T_l, params, 3, deriv = 2).y ./ (r_l[2] - r_l[1])^2
        laplace = second_deriv .+ (1.0./r_l) .* first_deriv
        push!(du2_dr, laplace)

    end

    #  α = zeros(length(du_dt), maximum(length.(du2_dr)))

    #  for (t, t_val) in enumerate(du_dt)
    #      for (x, x_val) in enumerate(du2_dr[t])
    #          α[t, x] = t_val / x_val
    #      end
    #  end
        
    if animate
        #  xlimits = (minimum(ri), maximum(ri))
        #  ylimits = (minimum(Ti) - 5, maximum(maxes) + 2)
        #  anim = @animate for i ∈ 1:frames
        #      index = dropoff_idx + i
        #      r = collect(keys(T_data[index]))
        #      T = collect(values(T_data[index]))
        #      l = @layout [
        #          a{0.4w} b{0.6w}
        #      ]

        #      sctr_plt = scatter(
        #              plt_anim,
        #              r,
        #              T,
        #              xlim = xlimits,
        #              ylim = ylimits,
        #              xlabel = "Radial distance (μm)",
        #              ylabel = "Temperature (K)",
        #              label = "Data",
        #              legend = :topright,
        #          )
        #      twin_sctr = twinx(sctr_plt)
        #      plot!(
        #          twin_sctr,
        #          r,
        #          du2_dr[i + 1],
        #          label = "Δ(T)",
        #          legend = :right,
        #          ylim = (minimum(du2_dr[1]), maximum(du2_dr[1])*100)
        #      )
        #      plot(
        #          sctr_plt,
        #          surface(
        #              x_grid,
        #              y_grid,
        #              Mat[index],
        #              xlabel = "x-position (μm)",
        #              ylabel = "y-position (μm)",
        #              zlabel = "Temperature (K)",
        #              zlims = ylimits,
        #              clims = ylimits,
        #          ),
        #          size = (1920, 1080),
        #          title = "Animation of temperature over time (frame $index)",
        #          layout = l,
        #      )
        #  end
        #  mp4(anim, "./output/flattening.mp4", fps = 24)
       
    ylimits = (minimum(T_by_rad[end]), maximum(filter(!isnan, T_by_rad[1])))
        println(T_by_rad[1])
        anim = @animate for T_vec ∈ T_by_rad  
            p1 = plot(
                T_vec,
                label="Data",
                xlabel="Time (s)",
                ylabel="Temperature (K)",
                legend=:topright,
            ) 
            ylims!(p1, ylimits)
        end
        mp4(anim, "./output/radial_T_vs_time.mp4", fps = 24)
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
        
        #  p3 = surface(α)
        p4 = plot(du_dt)

        savefig(p1, "./output/drop_off_location.png")
        savefig(p2, "./output/drop_off_distribution.png")
        #  savefig(p3, "./output/diffusivity.png")
        savefig(p4, "./output/du_dt.png")
    end
end
