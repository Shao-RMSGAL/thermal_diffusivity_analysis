module ThermalDiffusivityGUI

using Distributed: @everywhere, @sync, @distributed
using CSV: read, write
using DataFrames: DataFrame
using Gtk4
using Interpolations: linear_interpolation, Line, interpolate, BSpline, Quadratic, OnGrid
using OrderedCollections: OrderedDict
using Plots
using Plots.Measures
using SavitzkyGolay
using SharedArrays: SharedArray
using Statistics: mean, std
using Unitful

include("structs.jl")
include("analysis.jl")
include("diffusivitycalculation.jl")
include("framedataanalysis.jl")
include("gui.jl")
include("interpolation.jl")
include("output.jl")
include("videoparsing.jl")
"""
    julia_main()
Run the main program
"""
function julia_main()::Cint
    try
        main()
    catch
        Base.invokelatest(Base.display_error, Base.catch_stack())
        return 1
    end
    return 0
end

end # module ThermalDiffusivityGUI
