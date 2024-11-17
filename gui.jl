using Gtk4
using Distributed
using CSV

@everywhere include("analysis.jl")
include("diffusivitycalculation.jl")
include("output.jl")

function performanalysis(filename)
    if filename == ""
        error("No file selected.")
    end
    options = Options(filename = filename)
    diffusivitydata = run_analysis(options)
    interestdata, α = diffusivitycalculation(diffusivitydata, options)
    animation = plotdropoff_flattening(diffusivitydata, interestdata, options)
    return animation, interestdata, α
end

filenames = open_dialog(
    "Pick file(s) to analyse",
    nothing,
    ["*.csv"];
    start_folder = "./BoxData",
    multiple = true,
)

if filenames[1] == ""
    error("No file selected. Cancelled.")
end

@info "Files selected:" filenames

location = open_dialog("Save the output", nothing; select_folder = true, start_folder = "./output")
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
        "Average Radial Temperature (°C)"=>item["Average Radial Temperatures"],
        "Radius (μm)"=>collect(item["Radii"]),
        "∇²T (K/μm²)"=>item["∇²T"],
        "δT/δt (K/s)"=>item["δT/δt"],
        "α (μm²/s)"=>item["α"],
        )
        if !isdir(joinpath(dirname,"data"))
            mkdir(joinpath(dirname,"data"))
        end
        CSV.write(joinpath(dirname, "data", "frame_$frame.csv"), df)
        CSV.write(joinpath(dirname, "diffusivity.csv"), DataFrame("Diffusivity (mm²/s)"=>α[1],"Uncertainty (mm²/s)"=>α[2]))
    end
    @info "Saved analysis:" dirname
end
