using CSV
using DataFrames
using Unitful
using Plots
using Gtk4
using Interpolations
using Statistics

function parse_thermal_video(file_path)
    # Read the entire file
    data = readlines(file_path)
   
    # Extract auxiliary data
    aux_data = Dict{String, Any}()
    for i in 1:14
        parts = split(data[i], ',', limit=3)
        if length(parts) == 3
            key = strip(parts[2], ':')
            value = strip(parts[3])
            if occursin("°C", value)
                value = parse(Float64, split(value)[1]) * u"°C"
            elseif occursin("%", value)
                value = parse(Float64, split(value)[1]) * u"percent"
            elseif occursin("m", value)
                value = parse(Float64, split(value)[1]) * u"m"
            else
                value = try
                    parse(Float64, value)
                catch
                    value
                end
            end
            aux_data[key] = value
        end
    end

    # Extract frame data
    frame_data = Vector{Matrix{Float64}}()
    current_frame = Vector{Vector{Float64}}()
    
    for line in data[15:end]
        if startswith(line, "Frame")
            if !isempty(current_frame)
                push!(frame_data, reduce(vcat, transpose.(current_frame)))
                current_frame = Vector{Vector{Float64}}()
            else
                push!(current_frame, parse.(Float64, split(line, ',')[2:end]))
            end
        elseif !isempty(strip(line))
            split_line = split(line, ',')
            if split_line[end] == ""
                parsed_line = parse.(Float64, split_line[2:end - 1])
                push!(current_frame, parsed_line)
            else
                parsed_line = parse.(Float64, split_line[2:end])
                push!(current_frame, parsed_line)
            end
        end
    end
    
    # Add the last frame if it exists
    if !isempty(current_frame)
        push!(frame_data, reduce(vcat, transpose.(current_frame)))
    end

    for i in 1:size(frame_data, 1)
        frame_data[i] .+= 273.15
    end

    return aux_data, frame_data
end


function find_hotspot_center(matrix)

    # pixel_length = 0.25u"mm"

    max_value = maximum(matrix)
    rows, cols = size(matrix)
    
    max_positions = Tuple{Int, Int}[]
    
    for i in 1:rows
        for j in 1:cols
            if matrix[i, j] >= max_value - 0.0001*max_value
                push!(max_positions, (i, j))
            end
        end
    end
    
    if isempty(max_positions)
        error("No maximum found. This should not happen with a non-empty matrix.")
    end
    
    total_x = sum(pos[2] for pos in max_positions)
    total_y = sum(pos[1] for pos in max_positions)
    count = length(max_positions)
    
    avg_x = total_x / count
    avg_y = total_y / count
    
    return (round(Int, avg_x), round(Int, avg_y))
end

function create_file_selector_window()
    # Create the main window
    win = GtkWindow("File Selector")
    set_default_size(win, 800, 500)

    # Create a vertical box to organize widgets
    vbox = GtkBox(:v)
    push!(win, vbox)

    # Create a button to open the file chooser dialog
    choose_button = GtkButton("Choose File")
    push!(vbox, choose_button)

    # Create a label to display the selected file path
    file_label = GtkLabel("No file selected")
    push!(vbox, file_label)

    # Create the "Run Analysis" button
    run_button = GtkButton("Run Analysis")
    # Gtk4.set_sensitive(run_button, false)  # Disable initially
    push!(vbox, run_button)

    # Function to handle file selection
    function on_file_chosen(path)
        Gtk4.text(file_label, path)
        # set_sensitive(run_button, true)  # Enable the Run Analysis button
    end

    # Set up the file chooser dialog
    function open_file_chooser(widget)
        dialog = GtkFileChooserDialog("Choose a file", widget, Gtk4.FileChooserAction_OPEN,
                                      ("_Cancel", Gtk4.ResponseType_CANCEL,
                                       "_Open", Gtk4.ResponseType_ACCEPT))
        response = run(dialog)
        if response == Gtk4.ResponseType_ACCEPT
            #  file_path = get_filename(dialog)
            on_file_chosen(file_path)
        end
        destroy(dialog)
    end

    # Connect the Choose File button to the file chooser function
    signal_connect(open_file_chooser, choose_button, "clicked")

    # Connect the Run Analysis button to the analysis function
    signal_connect(run_button, "clicked") do widget
        file_path = get_text(file_label)
        run_analysis(file_path)
    end

    # Show all widgets
    show(win)
end

function print_aux_data(aux_data, frame_data)
    # Print auxiliary data
    for (key, value) in aux_data
        println("$key: $value")
    end
    # Print information about frame data
    println("\nNumber of frames: $(length(frame_data))")
    println("Dimensions of first frame: $(size(frame_data[1]))\n")
    
end

function interpolate_data(frame_data, dims)
        itp = interpolate(frame_data, BSpline(Quadratic(Line(OnGrid()))))
        x_range = range(1, size(frame_data, 1), length = dims[1])
        y_range = range(1, size(frame_data, 2), length = dims[2])
        matrix = zeros(dims[1], dims[2])
        
        for x in eachindex(x_range)
            for y in eachindex(y_range)
                matrix[x, y] = itp(x_range[x], y_range[y]) 
            end
        end

        return matrix
end

function extract_circle_average_temp(matrix, slices, x, y, scale_dist, rad_slices)
    radii = range(1, minimum(size(matrix))/2, length = slices - 1)
    T̅ = Dict{Float64, Float64}()
    θ = range(0, 2π, rad_slices)
    for r in radii
        x₁ = round.(Int, x .+ r * cos.(θ))
        y₁ = round.(Int, y .+ r * sin.(θ))
        try
            T̅[r * scale_dist] = mean([matrix[i, j] for (i, j) in zip(x₁, y₁)])
        catch e
            break
        end
    end
    return T̅
end 

# Define the run_analysis function (replace with your actual analysis logic)
function run_analysis(file_path, start_frame, end_frame, dims, scale_dist, slices, rad_slices, do_graphing)
    println("Running analysis on file: $file_path")
    aux_data, frame_data = parse_thermal_video(file_path)
    if start_frame == 0
        start_frame = 1
    end
    if end_frame == 0
        end_frame = size(frame_data, 1)
    end

    print_aux_data(aux_data, frame_data)

    x_range = range(0, size(frame_data[1], 1) * scale_dist, dims[1])
    y_range = range(0, size(frame_data[1], 2) * scale_dist, dims[2])

    average_radial_temperatures = [ Dict{Float64, Float64}() for _ in 1:(end_frame - start_frame + 1)]
    maxes = zeros(end_frame - start_frame + 1)


    for idx in start_frame:end_frame 
        matrix = interpolate_data(frame_data[idx], dims)
        (x,y) = find_hotspot_center(matrix)
        
        #println("Frame $idx Max (K), $(matrix[x,y])")
        maxes[idx - start_frame + 1] = matrix[x,y] 
        average_radial_temperatures[idx - start_frame + 1] = 
            extract_circle_average_temp(matrix, slices, x, y, scale_dist, rad_slices)

        # ϕ = 22.5u"°" 
        frac = 0.5
        r = round(Int, frac * minimum(dims)/2)
        θ = range(0, 2π, length = 100)
        x₁ = round.(Int, x .+ r * cos.(θ))
        y₁ = round.(Int, y .+ r * sin.(θ))
        circ_data = [maximum(matrix) for _ in θ]

        if do_graphing
            gr()
            plotlyjs()
            default(
                # aspect_ratio = :equal,
                legend = :topleft,
                xlabel = "x (μm)",
                ylabel = "y (μm)",
                zlabel = "Temp (K)",
                title = "Temperature of Frame $idx",
                xlims = (minimum(x_range), maximum(x_range)),
                ylims = (minimum(y_range), maximum(y_range))
            )
            p1 = surface(
                        x_range,
                        y_range,
                        matrix,
                        levels = 20,
                        fill=true,
                        aspect_ratio=:equal
            )
            scatter!(
                    p1,
                    [x_range[x]],
                    [y_range[y]],
                    [matrix[x,y]],
                    label = "Max: $(round(matrix[x, y], sigdigits = 4)) K"
            )
            plot!(
                    p1,
                    x_range[CartesianIndex.(x₁)],
                    y_range[CartesianIndex.(y₁)],
                    circ_data,
                    label = "Circle",
                    width = 10
            )
            gui(p1)
        end
    end

    return average_radial_temperatures, maxes

end

# Modify this data!
show_temp_over_time = true # Show temperature for multiple frames
do_graphing = false # Only enable if you are investigating a single frame
rad_slices = 100 # Number of slices to break a circle into along the circumerence
slices = 100 # Number of radius slices to extract average temperature from
scale_dist = 250 # Length of each pixel in μm
interpolation_points = (100, 100) # First is x, second is y.
start_frame = 0 # Starting with this frame (set to 0 to start from the beginning)
end_frame = 0 # Up to and including this frame (set to 0 to go to the end)
file_path = "./BoxData/Q 200 Cermic 2.csv" # File name
output_directory = "./output"   # Output directory 
                                # (warning, this will generate end_frame - start_frame .cvs 
                                # files in the directory you specify. Ensure the directory exists.)

# To run this analysis rapidly, copy this function. Then in the local directory, 
# run this:
    # julia --project =. -i thermal_diffusivity_analysis.jl
# This will run the analysis for the first time. It will take the longest, but
# subsequent runs will be faster. Without exiting the Julia "command line",
# make any desired modifications to the code, save it, then type
    # include("thermal_diffusivity_analysis")
# To run the script again quickly. If you run the first line, you will be restarting 
# julia over and over, which will take a long time.
T_data, maxes = run_analysis(
    file_path,
    start_frame,
    end_frame,
    interpolation_points,
    scale_dist,
    slices, 
    rad_slices, 
    do_graphing
)

if show_temp_over_time
    gr()
    default(
    )
    plot(maxes, 
        label = "Temperature (K)",
        title = "Max temperature over time",
        xlabel = "Frame",
        ylabel = "Temperature (K)"
    )
    gui()
end

for (idx, frame) in enumerate(T_data)
    df = DataFrame("Radius (μm)" => collect(keys(frame)), "Temperature (K)" => collect(values(frame)))
    CSV.write("$output_directory/frame_$(start_frame + idx - 1).csv", df)
end
