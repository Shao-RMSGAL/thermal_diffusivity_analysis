using CSV
using DataFrames
using Unitful
using Plots
using Interpolations
using Statistics
using SavitzkyGolay

include("analysis.jl")
include("interpolation.jl")
include("output.jl")
include("filtering.jl")

# Modify this data!
write_output = false # Write temperature over time data to CSV 
show_temp_over_time = false # Show temperature for multiple frames
do_graphing = false # Only enable if you are investigating a single frame
rad_slices = 100 # Number of slices to break a circle into along the circumerence
slices = 100 # Number of radius slices to extract average temperature from
scale_dist = 250 # Length of each pixel in μm
interpolation_points = (100, 100) # First is x, second is y.
start_frame = 0 # Starting with this frame (set to 0 to start from the beginning)
end_frame = 0 # Up to and including this frame (set to 0 to go to the end)
file_path = "./BoxData/Q 200 Cermic 2.csv" # File name
#  file_path = "./BoxData/Q 200 Silver 1.csv" # File name
#  file_path = "./Sample2_Extracted Data/Sample2 100 M1.csv" # File name
output_directory = "./output"   # Output directory
frame_rate = 24.0 # Framerate
# (warning, this will generate end_frame - start_frame .cvs
# files in the directory you specify. Ensure the directory exists.)

# To run this analysis rapidly, copy this function. Then in the local directory,
# run this:
# julia --project=. -i thermal_diffusivity_analysis.jl
# This will run the analysis for the first time. It will take the longest, but
# subsequent runs will be faster. Without exiting the Julia "command line",
# make any desired modifications to the code, save it, then type
# include("thermal_diffusivity_analysis")
# To run the script again quickly. If you run the first line, you will be restarting
# julia over and over, which will take a long time.
T_data, maxes, Mat, frame_size = run_analysis(
    file_path,
    start_frame,
    end_frame,
    interpolation_points,
    scale_dist,
    slices,
    rad_slices,
    do_graphing,
)

gr()
if show_temp_over_time
    default()
    plot(
        maxes,
        label = "Temperature (K)",
        title = "Max temperature over time",
        xlabel = "Frame",
        ylabel = "Temperature (K)",
    )
    gui()
end

if write_output
    for (idx, frame) in enumerate(T_data)
        df = DataFrame(
        "Radius (μm)" => collect(keys(frame)),
        "Temperature (K)" => collect(values(frame)),
        )
        CSV.write("$output_directory/frame_$(start_frame + idx - 1).csv", df)
    end
end

diffusivity_calculation(T_data, maxes, Mat, frame_size, scale_dist, false, true, frame_rate)
