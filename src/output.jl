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

"""
    plotdropoff_flattening(data::DataFrame, options::Options)
Create an animated plot of the radial temperature distribution
alongside the surface plot.
"""
function plotdropoff_flattening(totaldata::DataFrame, data::DataFrame, options::Options)
    #  @warn data[!, "Centers"]
    gr()
    @info "Starting dropoff plotting"
    radii = data[!, "Radii"]
    radialtempbyframe = data[!, "Average Radial Temperatures"]
    maxes = data[!, "Maximum Temperatures"]
    tempmatrixovertime = data[!, "Interpolated Temperature Matrix"]
    allmaxes = totaldata[!, "Maximum Temperatures"]
    laplacian_over_radius = data[!, "∇²T"]
    timederivative_over_radius = data[!, "δT/δt"]
    framecount = length(radialtempbyframe)
    ylimitsdata = (minimum(minimum.(radialtempbyframe)), maximum(maxes))
    ylimitssurface = (minimum(minimum.(tempmatrixovertime)), maximum(maxes))
    ylimitslaplacian =
        (minimum(minimum.(laplacian_over_radius)), maximum(maximum.(laplacian_over_radius)))
    ylimitstimederiv =
        (minimum(minimum.(timederivative_over_radius)), maximum(maximum.(timederivative_over_radius)))
    framesize = (data[1, "Frame size"])
    frameofdropoff = findfirst(isequal(data[1, "Frame"]), totaldata[!, "Frame"])
    xgrid = collect(
        range(
            0,
            framesize[1] - 1,
            length=options.interpolationpoints[1],
        ) * options.scaledistance,
    )
    ygrid = collect(
        range(
            0,
            framesize[2] - 1,
            length=options.interpolationpoints[2],
        ) * options.scaledistance,
    )

    window = round_to_odd(11)
    params = 5
    @info "Filtering settings" window params
    filtered = savitzky_golay(allmaxes, window, params, deriv=0).y

    anim = @animate for i ∈ 1:framecount
        l = @layout [a b{0.6w,1.0h}; c{0.3h}]

        scatterplot = scatter(
            radii[i],
            radialtempbyframe[i],
            xformatter=_ -> "",
            ylim=ylimitsdata,
            ylabel="T (°C)",
            legend=false,
        )
        laplacian = laplacian_over_radius[i]
        timederivative = timederivative_over_radius[i]
        laplaceplot = plot(
            collect(radii[i]),
            laplacian * 1.0e6,
            xlabel="Radial distance (μm)",
            ylabel="∇²T (K/mm²)",
            legend=false,
            ylim=ylimitslaplacian .* 1.0e6,
        )
        timederivplot = plot(
            collect(radii[i]),
            timederivative,
            xformatter=_ -> "",
            ylabel="δT/δt (K/s)",
            legend=false,
            ylim=ylimitstimederiv,
        )
        surf = surface(
            xgrid,
            ygrid,
            tempmatrixovertime[i],
            xlabel="x-position (μm)",
            ylabel="y-position (μm)",
            zlabel="Temperature (K)",
            xtickfontsize=8,
            ytickfontsize=8,
            ztickfontsize=8,
            ctickfontsize=8,
            xguidefontsize=8,
            yguidefontsize=8,
            zguidefontsize=8,
            zlims=ylimitssurface,
            clims=ylimitssurface,
            size=(1920, 1080,),
            margin=0mm,
        )
        #  surf = contour(
        #      xgrid,
        #      ygrid,
        #      tempmatrixovertime[i],
        #      xlabel="x-position (μm)",
        #      ylabel="y-position (μm)",
        #      xtickfontsize=8,
        #      ytickfontsize=8,
        #      ctickfontsize=8,
        #      xguidefontsize=8,
        #      yguidefontsize=8,
        #      zguidefontsize=8,
        #      clims=ylimitssurface,
        #      size=(1920, 1080,),
        #      margin=0mm,
        #  )
        x_coord = data[!, "Centers"][i][1] / options.interpolationpoints[1] * options.scaledistance * data[!, "Frame size"][1][1]
        y_coord = data[!, "Centers"][i][2] / options.interpolationpoints[2] * options.scaledistance * data[!, "Frame size"][1][2]
        plot!(
            [x_coord, x_coord], # Hack for centerpoint visualization
            [y_coord, y_coord],
            [tempmatrixovertime[i][data[!, "Centers"][i]], tempmatrixovertime[i][data[!, "Centers"][i]] - 1.0],
            #  data[!, "Maximum Temperatures"][i] + 10],
            linewidth=5,
            #  label="Central hotspot"
            legend=false
        )
        #  scatter!(
        #      [x_coord], # Hack for centerpoint visualization
        #      [y_coord],
        #      legend=false
        #  )
        radialtempplot = plot(
            scatterplot,
            timederivplot,
            laplaceplot,
            layout=grid(3, 1),
        )
        fullrange = plot(
            allmaxes,
            xlabel="Frame",
            ylabel="Maximum Temperature (°C)",
            label="Data",
            legend=:topright,
        )
        plot!(
            filtered,
            label="Smoothed",
        )
        vline!(
            fullrange,
            [frameofdropoff],
            style=:dash,
            label="Dropoff frame $frameofdropoff"
        )
        vline!(
            fullrange,
            [frameofdropoff + i],
            style=:dash,
            label="Current frame $(frameofdropoff + i)"
        )
        plot(
            radialtempplot,
            surf,
            fullrange,
            size=(3840, 2160),
            left_margin=[12mm 12mm],
            bottom_margin=[12mm 12mm],
            suptitle="$(splitdir(options.filename)[end])\nAnimation of temperature over time (frame $(data[i, "Frame"]))",
            layout=l,
        )
    end
    @info "Dropoff plotting complete"
    return anim
end

#  function produceplots(totaldata::DataFrame, interestdata::DataFrame)
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
#  end
