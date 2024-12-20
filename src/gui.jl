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
    opendatafiles(win, programparameters)
Prompt the user for a data file.
"""
function opendatafiles(win, programparameters, filelabel)
    @info "opendatafiles() called"
    if !isdir("./data")
        mkdir("./data")
    end
    datadir = "./data"

    function handlechoice(chosenfilenames)::Nothing
        @info "handlechoice() called with " chosenfilenames
        if isempty(chosenfilenames)
            @info "No data file chosen."
            return nothing 
        end
        programparameters.filenames = chosenfilenames
        filelabel.label = ""
        for filename ∈ chosenfilenames
            filelabel.label *= filename * "\n"
        end
        @info "Set " programparameters.filenames
        nothing
    end

    @info "Opening data file dialog"
    open_dialog(
        handlechoice,
        "Pick file(s) to analyse",
        win,
        ["*.csv"];
        start_folder = datadir,
        multiple = true,
    )
    @info "Data file dialog complete"
    nothing
end

"""
    chooseoutputdir()
Prompt the user for an output directory.
"""
function chooseoutputdir(win)
    if !isdir("./output")
        mkdir("./output")
    end
    outputdir = "./output"
    outputdir = open_dialog(
        "Save the output",
        win;
        select_folder = true,
        start_folder = outputdir,
    )
    if outputdir == ""
        error("No file selected. Cancelled.")
    else 
        @info "Output directory selected:" outputdir
        return outputdir
    end

end

"""
    analyzedatafiles(datafiles, outputdir)

Takes datafiles and an output directory, and conducts an analysis on them.
"""
function analyzedatafiles(programparameters)

    filenames = programparameters.filenames
    outputdir = programparameters.outputdir

    for filename in filenames

        @info "Analysing:" filename
        animation, interestdata, α = performanalysis(filename)

        # Create folder
        dirname = joinpath(outputdir, split(splitdir(filename)[end], ".")[1])
        if !isdir(dirname)
            mkdir(dirname)
        end

        gif(animation, joinpath(dirname, "flattening.gif"), fps = 10)
        for item in eachrow(interestdata)
            frame = item.Frame
            df = DataFrame(
            "Radius (μm)" => vcat([0], collect(item["Radii"])),
            "Average Radial Temperature (°C)" =>
                vcat(item["Maximum Temperatures"], item["Average Radial Temperatures"]),
                "∇²T (K/μm²)" => vcat([0],item["∇²T"]),
                "δT/δt (K/s)" => vcat([0], item["δT/δt"]),
                "α (μm²/s)" => vcat([0], item["α"]),
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

"""
    addfileactions()
Adds Gtk actions to the buttons in the interface.
"""
function addfileactions(win, programparameters, label)

    function choosedatafilecallback(_, _)::Nothing
        @info "choosedatafilecallback() called"
        opendatafiles(win, programparameters, label)
        @info "Attempting to set " programparameters.filenames
        nothing
    end

    #  function chooseoutputdircallback(a, par)::Nothing
    #       programparameters.outputdir = chooseoutputdir(win)
    #  end

    #  function runanalysiscallback(a, par)::Nothing
    #      analyzedatafiles(programparameters)
    #  end

    actiongroup = GSimpleActionGroup()
    add_action(GActionMap(actiongroup), "choosedatafiles", choosedatafilecallback)
    #  add_action(GActionMap(actiongroup), "chooseoutputdir", chooseoutputdircallback)
    #  add_action(GActionMap(actiongroup), "runanalysis", runanalysiscallback)
    push!(win, Gtk4.GLib.GActionGroup(actiongroup), "win")

end

mutable struct parameters
    filenames::Vector{String}
    outputdir::String
end


"""
    createtooltips(labelsandentries)
Create tooltips for all labels and entries.
"""
function createtooltips(labelsandentries)
    set_gtk_property!(labelsandentries[1][1], "has-tooltip", true)
    set_gtk_property!(labelsandentries[1][1], "tooltip-text", "The files which will be analyzed.")
    set_gtk_property!(labelsandentries[2][1], "has-tooltip", true)
    set_gtk_property!(labelsandentries[2][1], "tooltip-text", "The distance represented by a single pixel in the data being analyzed.")
    set_gtk_property!(labelsandentries[3][1], "has-tooltip", true)
    set_gtk_property!(labelsandentries[3][1], "tooltip-text", "Used to determine the minium absolute. value of the time derivative of temperature to consider for diffusivity calculations.")
    set_gtk_property!(labelsandentries[4][1], "has-tooltip", true)
    set_gtk_property!(labelsandentries[4][1], "tooltip-text", "Used to determine the minimum absolute value for the Laplacian of temperature to consider for diffusivity coefficient calculations.")
end

"""
    main()
Complete analysis with userprompt.
"""
function main()
    GLib.start_main_loop()
    win = GtkWindow("ThermalDiffusivityGUI", 400, 200)
    toplabel = GtkLabel("Thermal Diffusivity")

    labelsandentries = [
    (GtkLabel("Chosen Files: "),GtkLabel("")),
    (GtkLabel("Distance per pixel (μm)"),GtkEntry()),
    (GtkLabel("Temperature fluctuation threshold (°C)"),GtkEntry()),
    (GtkLabel("|∇²T| minimum threshold (K/mm²)"),GtkEntry()),
    (GtkLabel("|δT/δt| minimum threshold (K/s)"),GtkEntry()),
    ]
    labelsandentries[1][2].label = "Testing"
    createtooltips(labelsandentries)


    outervbox = GtkBox(:v)
    set_gtk_property!(outervbox, :vexpand, true)
    outerhbox = GtkBox(:h)
    labelgrid = GtkGrid()

    choosedatafilebutton = GtkButton("Choose Data File(s)")
    choosedatafilebutton.action_name = "win.choosedatafiles"

    chooseoutputdirbutton = GtkButton("Choose Output Folder")
    #  chooseoutputdirbutton.action_name = "win.chooseoutputdir"
    
    analyzebutton = GtkButton("Run Analysis")
    #  analyzebutton.action_name = "win.runanalysis"
    
    labelgrid[1, 1] = choosedatafilebutton
    labelgrid[2, 1] = chooseoutputdirbutton
    for (idx,pair) in enumerate(labelsandentries)
        labelgrid[1, idx + 1] = pair[1]
        labelgrid[2, idx + 1] = pair[2]
    end
    push!(outervbox, toplabel)
    push!(outervbox, outerhbox)
    push!(outerhbox, labelgrid)
    push!(outervbox, analyzebutton)
    push!(win, outervbox)

    programparameters = parameters([""], "") 
    addfileactions(win, programparameters, labelsandentries[1][2])
    show(win)

    if !isinteractive()
        c = Condition()
        signal_connect(win, :close_request) do widget
            notify(c)
        end
        @async Gtk4.GLib.glib_main()
        wait(c)
    end

end
