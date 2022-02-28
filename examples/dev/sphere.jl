# Utils
function module_dir()
    return joinpath(@__DIR__, "..", "..")
end

# Activate package
using Pkg
Pkg.activate(module_dir())

# Load packages
using MeshCat

# Open visualizer
vis=visualizer()
open(vis)

# Include new files
include(joinpath(module_dir(), "examples", "loader.jl"))


mech = getmechanism(:sphere, timestep=0.01, g = -9.81, contact = true);
initialize!(mech, :sphere, x = [0,0,1.0], ω = [3.0, 0,0])
@elapsed storage = simulate!(mech, 5.0, record=true, verbose=false, opts=SolverOptions(verbose=false, btol = 1e-6))
visualize(mech, storage, vis=vis)