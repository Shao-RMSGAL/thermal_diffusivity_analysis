# Modify this data!
struct Options
    write_output::Bool # Write temperature over time data to CSV
    do_graphing::Bool # Only enable if you are investigating a single frame
    rad_slices::Int64 # Number of slices to break a circle into along the circumerence. No need to change.
    slices::Int64 # Number of radius slices to extract average temperature from. No need to change.
    scale_dist::Int64 # Length of each pixel in μm
    interpolation_points::Tuple{Int64, Int64} # First is x, second is y. No need to change.
    start_frame::Int64 # Starting with this frame (set to 0 to start from the beginning)
    end_frame::Int64 # Up to and including this frame (set to 0 to go to the end)
    file_path::String # File name
    output_directory::String   # Output directory
    frame_rate::Float64 # Framerate
    animate::Bool # Only turn on if animating (will take longer)
        Options(;
        write_output::Bool = false,
        do_graphing::Bool = false,
        rad_slices::Int64 = 100,
        slices::Int64 = 100,
        scale_dist::Int64 = 250,
        interpolation_points::Tuple{Int64, Int64} = (100, 100),
        start_frame::Int64 = 0,
        end_frame::Int64 = 0,
        file_path::String = "",
        output_directory::String = "./output",
        frame_rate::Float64 = 24.0,
        animate::Bool = true,
        )   = new(
        write_output,
        do_graphing,
        rad_slices,
        slices,
        scale_dist,
        interpolation_points,
        start_frame,
        end_frame,
        file_path,
        output_directory,
        frame_rate,
        animate,
        )
    end
