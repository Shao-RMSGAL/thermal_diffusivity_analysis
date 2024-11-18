"""
    performanalysis(filename::String)
Perform analysis on the given file provided in the filename.
"""
function performanalysis(filename::String)
    if filename == ""
        error("No file selected.")
    end
    options = Options(filename = filename)
    diffusivitydata = run_analysis(options)
    interestdata, α = diffusivitycalculation(diffusivitydata, options)
    animation = plotdropoff_flattening(diffusivitydata, interestdata, options)
    return animation, interestdata, α
end

"""
    main()
Complete analysis with userprompt.
"""
function main()
    win = GtkWindow("ThermalDiffusivityGUI", 400, 200)
    toplabel = GtkLabel("Thermal Diffusivity")

    labelsandentries = [
    (GtkLabel("Current file: "),GtkLabel("")),
    (GtkLabel("Distance per pixel (μm)"),GtkEntry()),
    (GtkLabel("Temperature fluctuation threshold (°C)"),GtkEntry()),
    (GtkLabel("|∇²T| minimum threshold (K/mm²)"),GtkEntry()),
    (GtkLabel("|δT/δt| minimum threshold (K/s)"),GtkEntry()),
    ]

    set_gtk_property!(labelsandentries[1][1], "has-tooltip", true)
    set_gtk_property!(labelsandentries[1][1], "tooltip-text", "The file currently being analyzed.")
    set_gtk_property!(labelsandentries[2][1], "has-tooltip", true)
    set_gtk_property!(labelsandentries[2][1], "tooltip-text", "The distance represented by a single pixel in the data being analyzed.")
    set_gtk_property!(labelsandentries[3][1], "has-tooltip", true)
    set_gtk_property!(labelsandentries[3][1], "tooltip-text", "Used to determine the minium absolute. value of the time derivative of temperature to consider for diffusivity calculations.")
    set_gtk_property!(labelsandentries[4][1], "has-tooltip", true)
    set_gtk_property!(labelsandentries[4][1], "tooltip-text", "Used to determine the minimum absolute value for the Laplacian of temperature to consider for diffusivity coefficient calculations.")
    #  set_gtk_property!(labelsandentries[5][1], "has-tooltip", true)
    #  set_gtk_property!(labelsandentries[5][1], "tooltip-text", "Used to determine the minimum absolute value for the Laplacian of temperature to consider for diffusivity coefficient calculations.")


    outervbox = GtkBox(:v)
    set_gtk_property!(outervbox, :vexpand, true)
    outerhbox = GtkBox(:h)
    labelgrid = GtkGrid()
    display = GtkPicture("/home/nathaniel/Code/Julia/ThermalDiffusivityGUI/output/Sample2 700 M2/flattening.gif")

    for (idx,pair) in enumerate(labelsandentries)
        labelgrid[1, idx] = pair[1]
        labelgrid[2, idx] = pair[2]
    end

    push!(outervbox, toplabel)
    push!(outervbox, outerhbox)
    push!(outerhbox, labelgrid)
    push!(outervbox, display)
    push!(win, outervbox)
    show(win)

    filenames = open_dialog(
        "Pick file(s) to analyse",
        win,
        ["*.csv"];
        start_folder = "./data",
        multiple = true,
    )

    if isempty(filenames)
        error("No file selected. Cancelled.")
    end

    @info "Files selected:" filenames

    location = open_dialog(
        "Save the output",
        win;
        select_folder = true,
        start_folder = "./output",
    )
    if location == ""
        error("No file selected. Cancelled.")
    end

    @info "Output directory selected:" location

    for filename in filenames

        @info "Analysing:" filename
        animation, interestdata, α = performanalysis(filename)

        # Create folder
        dirname = joinpath(location, split(splitdir(filename)[end], ".")[1])
        if !isdir(dirname)
            mkdir(dirname)
        end

        gif(animation, joinpath(dirname, "flattening.gif"), fps = 10)
        for item in eachrow(interestdata)
            frame = item.Frame
            df = DataFrame(
                "Average Radial Temperature (°C)" =>
                    item["Average Radial Temperatures"],
                "Radius (μm)" => collect(item["Radii"]),
                "∇²T (K/μm²)" => item["∇²T"],
                "δT/δt (K/s)" => item["δT/δt"],
                "α (μm²/s)" => item["α"],
            )
            if !isdir(joinpath(dirname, "data"))
                mkdir(joinpath(dirname, "data"))
            end
            write(joinpath(dirname, "data", "frame_$frame.csv"), df)
            write(
                joinpath(dirname, "diffusivity.csv"),
                DataFrame("Diffusivity (mm²/s)" => α[1], "Uncertainty (mm²/s)" => α[2]),
            )
        end
        @info "Saved analysis:" dirname
    end
end
