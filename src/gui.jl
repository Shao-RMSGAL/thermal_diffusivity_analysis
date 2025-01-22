"""
    parsedata(filename)
This function accepts a filename string argument and returns a diffusivity
data calculated using the selected options.
"""
function parsedata(programparameters)
    options = programparameters.options
    @info "Parsing video data..." options
    if options.filename == ""
        @info "Bad filename" options.filename
        error("No file selected")
    end
    @info "success"
    return run_analysis(options)
end

"""
    performanalysis(filename::String)
Perform analysis on the given file provided in the filename.
"""
function performanalysis(programparameters)
    diffusivitydata = programparameters.diffusivitydata
    options = programparameters.options
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
    if !isdir("data")
        @info "Created 'data' directory. It is suggested to place all data here. Only CSV files are supported."
        mkdir("data")
    end
    datadir = "data"

    function handlechoice(chosenfilenames)::Nothing
        @async begin
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
            dropdown.model = GtkStringList(vcat(["Choose a file"], programparameters.filenames))
            if length(chosenfilenames) == 1
                @info "Single file chosen. Automatically setting selected to " chosenfilenames[1]
                dropdown.selected = 1
            end
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
        start_folder=datadir,
        multiple=true,
    )
    nothing
end

"""
    chooseoutputdir()
Prompt the user for an output directory.
"""
function chooseoutputdir(win, programparameters, outputlabel)
    @info "chooseoutputdir() called"
    if !isdir("output")
        @info "Created 'output' directory. It is suggested to use this directory to store all output."
        mkdir("output")
    end
    outputdir = "output"

    function handlechoice(chosenoutputdir)::Nothing
        @info "handlechoice() called with " chosenoutputdir
        if isempty(chosenoutputdir)
            @info "No output directory chosen. Output directory is " programparameters.outputdir
            return nothing
        end
        programparameters.outputdir = chosenoutputdir
        outputlabel.label = chosenoutputdir
        nothing
    end

    outputdir = open_dialog(
        handlechoice,
        "Save the output",
        win;
        select_folder=true,
        start_folder=outputdir,
    )
    nothing
end

"""
    generateanimation(datafiles, outputdir)

Takes datafiles and an output directory, and conducts an analysis on them.
"""
function generateanimation(programparameters)
    if programparameters.chosenfile == ""
        info_dialog(() -> nothing, "Please select files to analyze. Make sure to pick your file in the dropdown.", programparameters.window)
        error("No file chosen")
    elseif programparameters.outputdir == ""
        info_dialog(() -> nothing, "Please select an output directory.", programparameters.window)
        error("No output directory chosen")
    end
    filename = programparameters.chosenfile
    @info "Analysing:" filename
    animation, interestdata, α = performanalysis(programparameters)
    dirname = joinpath(programparameters.outputdir, split(splitdir(filename)[end], ".")[1])
    if !isdir(dirname)
        mkdir(dirname)
    end

    if programparameters.videooutputdropdown.selected == 2
        @info "Generating .gif"
        gif(animation, joinpath(dirname, "flattening.gif"), fps=programparameters.options.framerate)
    elseif programparameters.videooutputdropdown.selected == 1
        @info "Generating .mp4"
        mp4(animation, joinpath(dirname, "flattening.mp4"), fps=programparameters.options.framerate)
    else
        @info "No video output selected. Skipping video generation."
    end

    # Generate maxes in a separate file
    write(
        joinpath(dirname, "maxes_over_time.csv"),
        DataFrame("Frame" => programparameters.diffusivitydata[!, "Frame"], "Maximum Temperature" => programparameters.diffusivitydata[!, "Maximum Temperatures"]),
    )


    for item in eachrow(interestdata)
        frame = item.Frame
        df = DataFrame(
            "Radius (μm)" => vcat([0], collect(item["Radii"])),
            "Average Radial Temperature (°C)" =>
                vcat(item["Maximum Temperatures"], item["Average Radial Temperatures"]),
            "Average Radial Temperature Standard Deviation (°C)" =>
                vcat([0], item["Average Radial Temperatures Standard Deviation"]),
            "∇²T (K/μm²)" => vcat([0], item["∇²T"]),
            "δT/δt (K/s)" => vcat([0], item["δT/δt"]),
            "α (μm²/s)" => vcat([0], item["α"]),
        )
        if !isdir(joinpath(dirname, "data"))
            mkdir(joinpath(dirname, "data"))
        end
        write(joinpath(dirname, "data", "frame_$frame.csv"), df)
    end

    write(
        joinpath(dirname, "diffusivity.csv"),
        DataFrame("Diffusivity (mm²/s)" => α[1], "Uncertainty (mm²/s)" => α[2]),
    )
    @info "Saved analysis:" dirname
    @async info_dialog(() -> nothing, "Processing complete. Navigate to this directory\n $(joinpath(programparameters.outputdir, split(programparameters.chosenfile, ".")[1]))\n to see results.", programparameters.window)
    nothing
end

"""
    addfileactions()
Adds Gtk actions to the buttons in the interface.
"""
function addfileactions(programparameters) # , config)

    fileslabel = programparameters.fileslabel
    outputlabel = programparameters.outputlabel
    win = programparameters.window
    graph = programparameters.graph
    dropdown = programparameters.dropdown
    rerunbutton = programparameters.rerunbutton

    function updategraph()
        @async begin
            idx = dropdown.selected
            str = Gtk4.selected_string(dropdown)
            @info "Selected $idx which is $str"
            if idx != 0
                plotpath = joinpath(programparameters.outputdir, split(splitdir(str)[2], ".")[1], "max_plot.png")
                programparameters.chosenfile = str
                outputdir = split(splitdir(plotpath)[1], ".")[1]
                if !isdir(outputdir)
                    @info "Making directory at " outputdir
                    mkdir(outputdir)
                end
                try
                    @info "Parsing options..."
                    programparameters.options = Options(;
                        filename=programparameters.chosenfile,
                        scaledistance=parse(Float64, programparameters.distanceentry.text),
                        tempfluxthreshold=parse(Float64, programparameters.tempentry.text),
                        laplacianthreshold=parse(Float64, programparameters.laplacianentry.text) / 1000^2,
                        timederivativethreshold=parse(Float64, programparameters.timederivativeentry.text),
                        startframe=parse(Int, programparameters.startframeentry.text),
                        endframe=parse(Int, programparameters.endframeentry.text),
                        framerate=parse(Float64, programparameters.fpsentry.text),
                    )
                catch
                    @warn "One or more entries are malformed"
                    info_dialog(() -> nothing, "One of your entries is maformed. Correct the error and try again.", programparameters.window)
                    return nothing
                end
                @info "Options parsed" programparameters.options
                startframe = programparameters.options.startframe
                programparameters.diffusivitydata = parsedata(programparameters)
                default(; size=(800, 400))
                plot(startframe .+ programparameters.diffusivitydata[!, "Frame"],
                    programparameters.diffusivitydata[!, "Maximum Temperatures"], legend=false)
                title!("Plot of $(splitdir(str)[2]) Max Temps")
                xaxis!("Frame")
                yaxis!("Temperature (°C)")
                savefig(plotpath)
                @info "Saved new max plot at " plotpath
                Gtk4.G_.set_file(graph, Gtk4.GLib.GFile(plotpath))
            else
                programparameters.chosenfile = ""
                Gtk4.G_.set_file(graph, Gtk4.GLib.GFile(""))
            end
            nothing
        end
        nothing
    end
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

    function runanalysiscallback(_, _)::Nothing
        @info "runanalysiscallback() called"
        updategraph()
        generateanimation(programparameters)
        nothing
    end

    actiongroup = GSimpleActionGroup()
    add_action(GActionMap(actiongroup), "choosedatafiles", choosedatafilecallback)
    add_action(GActionMap(actiongroup), "chooseoutputdir", chooseoutputdircallback)
    add_action(GActionMap(actiongroup), "runanalysis", runanalysiscallback)
    push!(win, Gtk4.GLib.GActionGroup(actiongroup), "win")


    function updatefileselection(_, _)
        updategraph()
    end

    function rerunplot(_)
        updategraph()
    end

    signal_connect(updatefileselection, dropdown, "notify::selected")
    signal_connect(rerunplot, rerunbutton, "clicked")
end

mutable struct parameters
    filenames::Vector{String}
    outputdir::String
    diffusivitydata::DataFrame
    chosenfile::String
    options::Options
    window::GtkWindow
    fileslabel::GtkLabel
    outputlabel::GtkLabel
    distanceentry::GtkEntry
    tempentry::GtkEntry
    laplacianentry::GtkEntry
    timederivativeentry::GtkEntry
    startframeentry::GtkEntry
    endframeentry::GtkEntry
    dropdown::GtkDropDown
    rerunbutton::GtkButton
    fpsentry::GtkEntry
    videooutputdropdown::GtkDropDown
    graph::GtkPicture
end

"""
    createtooltips(labelsandentries)
Create tooltips for all labels and entries.
"""
function createtooltips(labelsandentries)
    set_gtk_property!(labelsandentries[1][1], "has-tooltip", true)
    set_gtk_property!(labelsandentries[1][1], "tooltip-text", "Select files to analyze. Multiple files can be selected, then chosen from the 'Current File' dropdown below.")
    set_gtk_property!(labelsandentries[1][2], "has-tooltip", true)
    set_gtk_property!(labelsandentries[1][2], "tooltip-text", "Select the output directory for data, including tabulated data, animated gif, and maximum temperature plot.")
    set_gtk_property!(labelsandentries[2][2], "has-tooltip", true)
    set_gtk_property!(labelsandentries[2][2], "tooltip-text", "The files which will be analyzed.")
    set_gtk_property!(labelsandentries[3][2], "has-tooltip", true)
    set_gtk_property!(labelsandentries[3][2], "tooltip-text", "The output directory. Defaults to the local 'output' directory.")
    set_gtk_property!(labelsandentries[4][2], "has-tooltip", true)
    set_gtk_property!(labelsandentries[4][2], "tooltip-text", "The distance represented by a single pixel in the data being analyzed.")
    set_gtk_property!(labelsandentries[5][2], "has-tooltip", true)
    set_gtk_property!(labelsandentries[5][2], "tooltip-text", "Determines when to stop dropoff plotting and diffusivity calculation through maximum and minimum temperature difference. If the temperature difference between the hottest point and the coldest point is less than this value, then plotting stops.")
    set_gtk_property!(labelsandentries[6][2], "has-tooltip", true)
    set_gtk_property!(labelsandentries[6][2], "tooltip-text", "Used to determine the minimum absolute value of the time derivative of temperature to consider for diffusivity calculations.")
    set_gtk_property!(labelsandentries[7][2], "has-tooltip", true)
    set_gtk_property!(labelsandentries[7][2], "tooltip-text", "Used to determine the minimum absolute value for the Laplacian of temperature to consider for diffusivity coefficient calculations.")
    set_gtk_property!(labelsandentries[8][2], "has-tooltip", true)
    set_gtk_property!(labelsandentries[8][2], "tooltip-text", "The first frame to consider for analysis. Leave at zero to start at the beginning.")
    set_gtk_property!(labelsandentries[9][2], "has-tooltip", true)
    set_gtk_property!(labelsandentries[9][2], "tooltip-text", "The last frame to consider for analysis. Leave at zero to go to the end.")
    set_gtk_property!(labelsandentries[10][2], "has-tooltip", true)
    set_gtk_property!(labelsandentries[10][2], "tooltip-text", "The file currently being analyzed. Select the file you would like to analyze from the dropdown. If you want a different selection, choose one or more files using the 'Choose Data File(s)' button.")
    set_gtk_property!(labelsandentries[11][1], "has-tooltip", true)
    set_gtk_property!(labelsandentries[11][1], "tooltip-text", "Run the complete analysis. This will calculate diffusivity data, generate tabular data, and create an animated gif.")
    set_gtk_property!(labelsandentries[11][2], "has-tooltip", true)
    set_gtk_property!(labelsandentries[11][2], "tooltip-text", "Rerun the plotting. This will just regenerate the plot on the left for you to see the current frame bounds that you applied, if you changed them.")
    set_gtk_property!(labelsandentries[12][2], "has-tooltip", true)
    set_gtk_property!(labelsandentries[12][2], "tooltip-text", "Control the frames per second of the output animation.")
    set_gtk_property!(labelsandentries[13][2], "has-tooltip", true)
    set_gtk_property!(labelsandentries[13][2], "tooltip-text", "Select the type of output for the animation. If none is selected, no video is produced. (Not producing a video can save time if it is not needed)")
end

"""
    main()
Complete analysis with userprompt.
"""
function main()
    GLib.start_main_loop()
    win = GtkWindow("ThermalDiffusivityGUI", 1600, 900)
    toplabel = GtkLabel("Thermal Diffusivity")

    if !isdir("output")
        mkdir("output")
    end

    options = Options()

    choosedatafilebutton = GtkButton("Choose Data File(s)"; action_name="win.choosedatafiles")
    chooseoutputdirbutton = GtkButton("Choose Output Folder"; action_name="win.chooseoutputdir")
    analyzebutton = GtkButton("Run Analysis"; action_name="win.runanalysis")
    rerunbutton = GtkButton("Rerun plot generation")

    labelsandentries = [
        (choosedatafilebutton, chooseoutputdirbutton),
        (GtkLabel("Chosen Files: "), GtkLabel("No files chosen")),
        (GtkLabel("Output Directory: "), GtkLabel(abspath("output"))),
        (GtkLabel("Distance per pixel (μm)"), GtkEntry(; text=options.scaledistance)),
        (GtkLabel("Temperature fluctuation threshold (°C)"), GtkEntry(; text=options.tempfluxthreshold)),
        (GtkLabel("|∇²T| minimum threshold (K/mm²)"), GtkEntry(; text=options.laplacianthreshold * 1000^2)),
        (GtkLabel("|δT/δt| minimum threshold (K/s)"), GtkEntry(; text=options.timederivativethreshold)),
        (GtkLabel("Start Frame"), GtkEntry(; text=options.startframe)),
        (GtkLabel("End Frame"), GtkEntry(; text=options.endframe)),
        (GtkLabel("Current File"), GtkDropDown(["No file selected"])),
        (analyzebutton, rerunbutton),
        (GtkLabel("Output FPS"), GtkEntry(; text=options.framerate)),
        (GtkLabel("Video output type"), GtkDropDown(["No Output", ".mp4", ".gif"]; selected=2)),
    ]
    createtooltips(labelsandentries)

    graph = GtkPicture("")

    programparameters = parameters(
        [""],
        abspath("output"),
        DataFrame(),
        "",
        options,
        win,
        labelsandentries[2][2],
        labelsandentries[3][2],
        labelsandentries[4][2],
        labelsandentries[5][2],
        labelsandentries[6][2],
        labelsandentries[7][2],
        labelsandentries[8][2],
        labelsandentries[9][2],
        labelsandentries[10][2],
        labelsandentries[11][2],
        labelsandentries[12][2],
        labelsandentries[13][2],
        graph,
    )

    outervbox = GtkBox(:v; vexpand=true, hexpand=true)
    labelgrid = GtkGrid()

    for (idx, pair) in enumerate(labelsandentries)
        labelgrid[1, idx] = pair[1]
        labelgrid[2, idx] = pair[2]
    end

    push!(outervbox, toplabel)
    push!(outervbox, labelgrid)

    top_paned = GtkPaned(:h; hexpand=true, position=1000)
    top_paned[1] = outervbox

    graphbox = GtkBox(:h; hexpand=true)
    push!(graphbox, graph)
    top_paned[2] = graphbox

    push!(win, top_paned)

    addfileactions(programparameters)
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
