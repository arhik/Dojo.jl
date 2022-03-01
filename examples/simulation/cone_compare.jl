using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
Pkg.instantiate()

# ## Setup
using Dojo

# ## Visualizer
vis= Visualizer()
open(vis)
set_camera!(vis,
    cam_pos=[-0.01, 0.0, 90.0],
    zoom=30)
set_floor!(vis,
    x=20.0,
    y=20.0,
    color=RGBA(1.0, 1.0, 1.0, 1.0))
set_light!(vis,
    ambient=0.65,
    direction="Positive")

################################################################################
# Nonlinear Friction Cone vs. Linearized Friction Cone
################################################################################
timestep = 0.01
gravity = -9.81
friction_coefficient = 0.25
x0 = [-1.5, -0.50, 0.25]
v0 = [4, 0.80, 0.0]
ω0 = [0.0, 0.0, 0.0]
opts = SolverOptions(rtol=1.0e-6, btol=1.0e-6)

# ## Linear cone
color_lc = orange;
mech_lc = get_mechanism(:box,
    timestep=timestep,
    gravity=gravity,
    friction_coefficient=friction_coefficient,
    contact_type=:linear,
    mode=:box,
    color=color_lc);

# ## Simulate
initialize!(mech_lc, :box,
    x=x0,
    q=one(UnitQuaternion),
    v=v0,
    ω=ω0)

storage_lc = simulate!(mech_lc, 4.0,
    record=true,
    opts=opts)

# ## Visualize
via, anim = visualize(mech_lc, storage_lc,
    vis=vis,
    name=:lc)


# ## Nonlinear cone
color_nc = cyan;
mech_nc = get_mechanism(:box,
    timestep=timestep,
    gravity=gravity,
    friction_coefficient=friction_coefficient,
    contact_type=:nonlinear,
    mode=:box,
    color=color_nc);

# ## Simulate
initialize!(mech_nc, :box,
    x=x0,
    q=one(UnitQuaternion),
    v=v0,
    ω=ω0)

storage_nc = simulate!(mech_nc, 4.0,
    record=true,
    opts=opts)

# ## Visualize
for (i, x) in enumerate(storage_nc.x[1])
    storage_nc.x[1][i] += [0.0; 0.0; 0.1]
end

vis, anim = visualize(mech_nc, storage_nc,
    vis=vis,
    name=:nc,
    animation=anim)

# ## MuJoCo cone
color_mj = magenta;

mech_mj = get_mechanism(:box,
    timestep=timestep,
    gravity=gravity,
    friction_coefficient=friction_coefficient,
    contact_type=:linear,
    mode=:box, color=color_mj);

# ## Load
initialize!(mech_mj, :box,
    x=x0,
    q=one(UnitQuaternion),
    v=v0,
    ω=ω0)
file = jldopen(joinpath(@__DIR__, "../MuJoCo_benchmark/results/cone_compare.jld2"))
storage_mj = generate_storage(mech_mj, [get_maximal_state(mech_mj), file["ztraj"]...])

# ## Visualize
vis, anim = visualize(mech_mj, storage_mj,
    vis=vis,
    name=:mj,
    animation=anim)


