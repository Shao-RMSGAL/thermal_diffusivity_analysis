"""
    struct Options

A struct for storing options for the thermal diffusivity analysis
"""
struct Options
    writeoutput::Bool # Write temperature over time data to CSV
    dographing::Bool # Only enable if you are investigating a single frame
    radialslices::Int64 # Number of slices to break a circle into along the circumerence. No need to change.
    slices::Int64 # Number of radius slices to extract average temperature from. No need to change.
    scaledistance::Float64 # Length of each pixel in μm
    interpolationpoints::Tuple{Int64,Int64} # First is x, second is y. No need to change.
    startframe::Int64 # Starting with this frame (set to 0 to start from the beginning)
    endframe::Int64 # Up to and including this frame (set to 0 to go to the end)
    filename::String # File name
    outputdirectory::String   # Output directory
    framerate::Float64 # Framerate
    animate::Bool # Only turn on if animating (will take longer)
    calibrationfilename::String # Location of calibration file
    minradius::Float64 # Minimum radius from the hotspot to start drawing radii (μm)
    tempfluxthreshold::Float64 # Temperature fluctuation threshold used for determining maximum temperatures
    laplacianthreshold::Float64 # Fluctuation threshold used to determine threshold for considering laplacian values 
    timederivativethreshold::Float64 # Fluctuation values used to determine threshold for considering time derivative values
    @doc """
        Options(;
            writeoutput::Bool = false,
            dographing::Bool = false,
            radialslices::Int64 = 100,
            slices::Int64 = 100,
            scaledistance::Float64 = 250.0,
            interpolationpoints::Tuple{Int64,Int64} = (100, 100),
            startframe::Int64 = 0,
            endframe::Int64 = 0,
            filename::String = "",
            outputdirectory::String = "abspath(output)",
            framerate::Float64 = 10.0,
            animate::Bool = true,
            calibrationfilename::String = abspath(joinpath("caliration", "calibration.csv")),
            tempfluxthreshold::Float64 = 5.0,
            laplacianthreshold::Float64 = 1.0,
            timederivativethreshold::Float64 = 5.0,
        )

    Construct an Options struct.

    All fields have default options that can be modified using keyword arguments.
    """
    Options(;
        writeoutput::Bool = false,
        dographing::Bool = false,
        radialslices::Int64 = 100,
        slices::Int64 = 100,
        scaledistance::Float64 = 250.0,
        interpolationpoints::Tuple{Int64,Int64} = (100, 100),
        startframe::Int64 = 0,
        endframe::Int64 = 0,
        filename::String = "",
        outputdirectory::String = abspath("output"),
        framerate::Float64 = 10.0,
        animate::Bool = true,
        calibrationfilename::String = abspath(joinpath("calibration", "calibration.csv")),
        minradius::Float64 = 1.0,
        tempfluxthreshold::Float64 = 5.0,
        laplacianthreshold::Float64 = 5.0e-6,
        timederivativethreshold::Float64 = 1.0,
    ) = new(
        writeoutput,
        dographing,
        radialslices,
        slices,
        scaledistance,
        interpolationpoints,
        startframe,
        endframe,
        filename,
        outputdirectory,
        framerate,
        animate,
        calibrationfilename,
        minradius,
        tempfluxthreshold,
        laplacianthreshold,
        timederivativethreshold,
    )
end
