using CSV
using DataFrames
using Unitful
using Plots
using Interpolations
using Statistics
using SavitzkyGolay
using Distributed

@everywhere include("analysis.jl")
include("diffusivitycalculation.jl")
include("structs.jl")

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
options = Options(
    filename = "./BoxData/Q 200 Silver 1.csv",
);
diffusivitydata = run_analysis(options)
interestdata = diffusivitycalculation(diffusivitydata, options)

plotdropoff_flattening(diffusivitydata, interestdata, options)

#  gr()

    #  for (idx, frame) in enumerate(T_data)
#          if options.writeoutput
#          df = DataFrame(
#              "Radius (μm)" => collect(keys(frame)),
#              "Temperature (K)" => collect(values(frame)),
#          )
#          CSV.write("$options.output_directory/frame_$(options.start_frame + idx - 1).csv", df)
#      end
#  end

#  diffusivity_calculation(
#      T_data,
#      maxes,
#      Mat,
#      frame_size,
#      options.scale_dist,
#      options.do_graphing,
#      options.animate,
#      options.frame_rate,
#      radii,
#      options.rad_slices,
#  )
