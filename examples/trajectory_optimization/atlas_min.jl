using Dojo
using IterativeLQR
using LinearAlgebra

# ## system
include(joinpath(@__DIR__, "../../env/atlas/methods/template.jl"))

gravity = -9.81
dt = 0.05
cf = 0.8
damper = 50.0
spring = 0.0
model_type = :armless
env = make("atlas",
    mode=:min,
    dt=dt,
    g=gravity,
    cf=cf,
    damper=damper,
    spring=spring,
	model_type=model_type)
quadruped()

# ## visualizer
open(env.vis)

# ## simulate (test)
# initialize!(env.mechanism, :quadruped)
# storage = simulate!(env.mechanism, 0.5, record=true, verbose=false)
# visualize(env.mechanism, storage, vis=env.vis)

# ## dimensions
n = env.nx
m = env.nu
d = 0

# ## reference trajectory
N = 1
initialize!(env.mechanism, :atlas)
xref = atlas_trajectory(env.mechanism; Δt=dt, r=0.0, x=0.03, z=0.85, N=12, Ncycles=N)
zref = [min2max(env.mechanism, x) for x in xref]
visualize(env, xref)
#
# storage = simulate!(env.mechanism, 0.1, record=true)
# visualize(env.mechanism, storage, vis=env.vis)
# center_of_mass(env.mechanism, storage, 1)

## gravity compensation TODO: solve optimization problem instead
mech = getmechanism(:atlas, Δt=dt, g=gravity, cf=cf, damper=1000.0,
	spring=spring, model_type=model_type)
initialize!(mech, :atlas)
storage = simulate!(mech, 0.10, record=true, verbose=false)
visualize(mech, storage, vis=env.vis)
# ugc = gravity_compensation(mech)
# u_control = ugc[6 .+ (1:15)]
F_damper = get_damperforce(env.mechanism)
u_damper = F_damper * env.mechanism.Δt
u_control = u_damper[6 .+ (1:15)]

mech = getmechanism(:atlas, Δt=dt, g=gravity, cf=cf, damper=0.0,
	spring=spring, model_type=model_type)
function controller!(mechanism, k)
    set_control!(mechanism, u_damper)
    return
end
initialize!(mech, :atlas, tran=[0,0,0.0])
storage = simulate!(mech, 0.50, controller!, record=true, verbose=false)
visualize(mech, storage, vis=env.vis)

function get_damperforce(mechanism::Mechanism{T}) where {T}
	eqcs = mechanism.eqconstraints
	# set the controls in the equality constraints
	off = 0
	nu = controldim(mechanism)
	u = zeros(nu)
	for eqc in eqcs
		pbody = getbody(mechanism, eqc.parentid)
		if typeof(pbody) <: Body
			F = damperforce(mechanism, eqc, pbody)
			oF = 0
			for joint in eqc.constraints
				nf, nF = size(nullspacemat(joint))
				u[off .+ (1:nf)] .= nullspacemat(joint) * F[oF .+ (1:nF)]
				off += nf
				oF += nF
			end
		else
			for joint in eqc.constraints
				nf, nF = size(nullspacemat(joint))
				off += nf
			end
		end
	end
	return u
end


# eqc0 = env.mechanism.eqconstraints.values[1]
# body0 = getbody(env.mechanism, eqc0.parentid)
# df = damperforce(mech, eqc0, body0)
# nullspacemat(eqc0.constraints[1])# * df[1:3]
# nullspacemat(eqc0.constraints[2])# * df[4:6]
# nf, nF = size(nullspacemat(eqc0.constraints[1]))
# nf
# null
# u = get_damperforce(env.mechanism)

# ## horizon
T = N * (25 - 1) + 1

# ## model
dyn = IterativeLQR.Dynamics(
    (y, x, u, w) -> f(y, env, x, u, w),
    (dx, x, u, w) -> fx(dx, env, x, u, w),
    (du, x, u, w) -> fu(du, env, x, u, w),
    n, n, m, d)

model = [dyn for t = 1:T-1]

# ## rollout
x1 = xref[1]
ū = [u_control for t = 1:T-1]
w = [zeros(d) for t = 1:T-1]
x̄ = IterativeLQR.rollout(model, x1, ū, w)
visualize(env, x̄)

# ## objective
qt = [0.3; 0.05; 0.05; 0.01 * ones(3); 0.01 * ones(3); 0.01 * ones(3); fill(0.002, 30)...]
ots = [(x, u, w) -> transpose(x - xref[t]) * Diagonal(dt * qt) * (x - xref[t]) + transpose(u) * Diagonal(dt * 0.002 * ones(m)) * u for t = 1:T-1]
oT = (x, u, w) -> transpose(x - xref[end]) * Diagonal(dt * qt) * (x - xref[end])

cts = IterativeLQR.Cost.(ots, n, m, d)
cT = IterativeLQR.Cost(oT, n, 0, 0)
obj = [cts..., cT]

# ## constraints
function goal(x, u, w)
    Δ = x - xref[end]
	Δ[3] -= 0.40
    return Δ[collect(1:3)]
end

cont = IterativeLQR.Constraint()
conT = IterativeLQR.Constraint(goal, n, 0)
cons = [[cont for t = 1:T-1]..., conT]

# ## problem
prob = IterativeLQR.problem_data(model, obj, cons)
IterativeLQR.initialize_controls!(prob, ū)
IterativeLQR.initialize_states!(prob, x̄)

# ## solve
IterativeLQR.solve!(prob,
    verbose = true,
	linesearch=:armijo,
    α_min=1.0e-5,
    obj_tol=1.0e-3,
    grad_tol=1.0e-3,
    max_iter=100,
    max_al_iter=5,
    ρ_init=1.0,
    ρ_scale=10.0)

vis = Visualizer()
open(env.vis)

# ## solution
x_sol, u_sol = IterativeLQR.get_trajectory(prob)
@show IterativeLQR.eval_obj(prob.m_data.obj.costs, prob.m_data.x, prob.m_data.u, prob.m_data.w)
@show prob.s_data.iter[1]
@show norm(goal(prob.m_data.x[T], zeros(0), zeros(0)), Inf)

# ## visualize
x_view = [[x_sol[1] for t = 1:15]..., x_sol..., [x_sol[end] for t = 1:15]...]
visualize(env, x_view)

set_camera!(env.vis, zoom=5, cam_pos=[0,-5,0])
z = [min2max(env.mechanism, x) for x in x_sol]
t = 1 #10, 20, 30, 41
set_robot(env.vis, env.mechanism, z[t])