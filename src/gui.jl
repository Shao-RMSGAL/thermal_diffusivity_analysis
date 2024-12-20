"""
    parsedata(filename)
This function accepts a filename string argument and returns a diffusivity
data calculated using the selected options.
"""
function parsedata(filename)
    @info "Parsing video data..."
    if filename == ""
        error("No file selected.")
    end
    options = Options(filename = filename) 
    @info "Parsing video data complete."
    return run_analysis(options)
end

"""
    performanalysis(filename::String)
Perform analysis on the given file provided in the filename.
"""
function performanalysis(diffusivitydata, options)
    interestdata, α = diffusivitycalculation(diffusivitydata, options)
    animation = plotdropoff_flattening(diffusivitydata, interestdata, options)
    return animation, interestdata, α
end


"""
    opendatafiles(win, programparameters)
Prompt the user for a data file.
"""
function opendatafiles(win, programparameters, filelabel, dropdown)
    @info "opendatafiles() called"
    if !isdir("./data")
        mkdir("./data")
    end
    datadir = "./data"

    function handlechoice(chosenfilenames)::Nothing
        @async begin
            @info "handlechoice() called with " chosenfilenames
            if isempty(chosenfilenames)
                @info "No data file chosen."
                return nothing 
            end
            programparameters.filenames = chosenfilenames
            filelabel.label = ""
            #  for filename ∈ chosenfilenames
                #      filelabel.label *= filename * "\n"
                #      push!(dropdown, filename)
            #  end
            dropdown.model =  GtkStringList(vcat(["Choose a file"],programparameters.filenames))
            @info "Set " programparameters.filenames
        end
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
    nothing
end

"""
    chooseoutputdir()
Prompt the user for an output directory.
"""
function chooseoutputdir(win, programparameters, outputlabel)
    @info "chooseoutputdir() called"
    if !isdir("./output")
        mkdir("./output")
    end
    outputdir = "./output"
 
    function handlechoice(chosenoutputdir)::Nothing
        @info "handlechoice() called with " chosenoutputdir
        if isempty(chosenoutputdir)
            @info "No output directory chosen."
            return nothing 
        end
        programparameters.outputdir = chosenoutputdir
        outputlabel.label =chosenoutputdir
        nothing
    end

    outputdir = open_dialog(
        handlechoice,
        "Save the output",
        win;
        select_folder = true,
        start_folder = outputdir,
    )
    nothing
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
function addfileactions(win, programparameters, fileslabel, outputlabel, dropdown)

    function choosedatafilecallback(_, _)::Nothing
        @info "choosedatafilecallback() called"
        opendatafiles(win, programparameters, fileslabel, dropdown)
        nothing
    end

    function chooseoutputdircallback(_, _)::Nothing
        @info "chooseoutputdircallback() called"
        chooseoutputdir(win, programparameters, outputlabel)
        nothing
    end

    function runanalysiscallback(a, par)::Nothing
        @info "runanalysiscallback() called"
        #  analyzedatafiles(programparameters)
    end

    actiongroup = GSimpleActionGroup()
    add_action(GActionMap(actiongroup), "choosedatafiles", choosedatafilecallback)
    add_action(GActionMap(actiongroup), "chooseoutputdir", chooseoutputdircallback)
    add_action(GActionMap(actiongroup), "runanalysis", runanalysiscallback)
    push!(win, Gtk4.GLib.GActionGroup(actiongroup), "win")
 
    signal_connect(dropdown, "notify::selected") do widget, others...
        idx = dropdown.selected
        str = Gtk4.selected_string(dropdown)
        @info "Selected " idx "which is" str
        if idx != 0
            programparameters.diffusivitydata = parsedata(str)
            plot(programparameters.diffusivitydata[!, "Maximum Temperatures"])
            savefig("max_plot.png")
        end
        nothing
    end
end

mutable struct parameters
    filenames::Vector{String}
    outputdir::String
    diffusivitydata::DataFrame
end

"""
    createtooltips(labelsandentries)
Create tooltips for all labels and entries.
"""
function createtooltips(labelsandentries)
    set_gtk_property!(labelsandentries[1][1], "has-tooltip", true)
    set_gtk_property!(labelsandentries[1][1], "tooltip-text", "The files which will be analyzed.")
    set_gtk_property!(labelsandentries[2][1], "has-tooltip", true)
    set_gtk_property!(labelsandentries[2][1], "tooltip-text", "The output directory.")
    set_gtk_property!(labelsandentries[3][1], "has-tooltip", true)
    set_gtk_property!(labelsandentries[3][1], "tooltip-text", "The distance represented by a single pixel in the data being analyzed.")
    set_gtk_property!(labelsandentries[4][1], "has-tooltip", true)
    set_gtk_property!(labelsandentries[4][1], "tooltip-text", "Used to determine the minimum absolute value of the time derivative of temperature to consider for diffusivity calculations.")
    set_gtk_property!(labelsandentries[5][1], "has-tooltip", true)
    set_gtk_property!(labelsandentries[5][1], "tooltip-text", "Used to determine the minimum absolute value for the Laplacian of temperature to consider for diffusivity coefficient calculations.")
end

"""
    main()
Complete analysis with userprompt.
"""
function main()

    programparameters = parameters([""], "", DataFrame()) 
   
    GLib.start_main_loop()
    win = GtkWindow("ThermalDiffusivityGUI", 400, 200)
    toplabel = GtkLabel("Thermal Diffusivity")

    labelsandentries = [
    (GtkLabel("Chosen Files: "),GtkLabel("No files chosen.")),
    (GtkLabel("Output Directory: "),GtkLabel("No output directory chosen.")),
    (GtkLabel("Distance per pixel (μm)"),GtkEntry()),
    (GtkLabel("Temperature fluctuation threshold (°C)"),GtkEntry()),
    (GtkLabel("|∇²T| minimum threshold (K/mm²)"),GtkEntry()),
    (GtkLabel("|δT/δt| minimum threshold (K/s)"),GtkEntry()),
    (GtkLabel("Current File"), GtkDropDown(["No file selected."]))
    ]
    createtooltips(labelsandentries)

    outervbox = GtkBox(:v)
    set_gtk_property!(outervbox, :vexpand, true)
    outerhbox = GtkBox(:h)
    labelgrid = GtkGrid()

    choosedatafilebutton = GtkButton("Choose Data File(s)"; action_name = "win.choosedatafiles")
    chooseoutputdirbutton = GtkButton("Choose Output Folder"; action_name = "win.chooseoutputdir") 
    analyzebutton = GtkButton("Run Analysis"; action_name = "win.runanalysis")

    skipbutton = GtkButton("Skip this file") 
    analyzeskiphbox = GtkBox(:h)
    analyzeskiphbox.hexpand = true

    push!(analyzeskiphbox, analyzebutton, skipbutton)

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
    push!(outervbox, analyzeskiphbox)
    push!(win, outervbox)

    addfileactions(win, programparameters, labelsandentries[1][2], labelsandentries[2][2], labelsandentries[7][2])
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
