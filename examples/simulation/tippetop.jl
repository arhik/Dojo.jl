# PREAMBLE

# PKG_SETUP

# ## Setup
using Dojo

# ## Mechanism
mech = get_mechanism(:tippetop, 
    timestep=0.01, 
    gravity=-9.81, 
    contact=true, 
    contact_type=:nonlinear)

# ## Simulate
initialize!(mech, :tippetop, 
    x=[0.0, 0.0, 1.0], 
    q=UnitQuaternion(RotX(0.01 * π)), 
    ω=[0.0, 0.01, 50.0])

storage = simulate!(mech, 25.0, 
    record=true, 
    verbose=false, 
    opts=SolverOptions(verbose=false, btol=1e-6))

# ## Open visualizer
vis=visualizer()
open(vis)
visualize(mech, storage, 
    vis=vis)