using MeshCat
using Plots

vis = Visualizer()
open(vis)

# mech = get_snake(damper=0.1)
# initialize!(mech, :snake)
mech = get_twister(damper=0.0, joint_type=:Revolute, num_bodies=3)
initialize!(mech, :twister)
# mech = get_snake(damper=0.0, joint_type=:Revolute, num_bodies=3)
# initialize!(mech, :snake)
storage = simulate!(mech, 0.5, record=true, opts=SolverOptions(btol=1e-4))
visualize(mech, storage, vis=vis)



mech = Dojo.get_mechanism(:pendulum,
    timestep=0.01,
    gravity=-0.0,
    spring=0.0,
    damper=0.5)
function ctrl!(m,k)
    set_input!(m, 0.000 * 1 *sones(1))
    return nothing
end
input_dimension(mech)
zero_velocity!(mech)
y = [0.0,10.50]
set_minimal_state!(mech, y)

storage = simulate!(mech, 5.0, Dojo.ctrl!, record=true)
visualize(mech, storage, vis=vis)
get_minimal_state(mech)
storage.ω[1]
plot([-ϕ[1] for ϕ in storage.ω[1]])

xa = szeros(3)
qa = Quaternions.QuaternionF64(1.0, 0.0, 0.0, 0.0, true)
xb = 0*[0.0, 0.4476047997637539, 0.8771773278369399]
qb = mech.bodies[1].state.q2
Q = displacement_jacobian_configuration(:child, mech.joints[1].rotational,
    szeros(3), qa, szeros(3), qb, attjac=true)[2]

VRᵀmat(qa) - VRmat(inv(qa))
LVᵀmat(qa) - LᵀVᵀmat(inv(qa))
VRᵀmat(inv(qb) * qa) * LVᵀmat(inv(qb) * qa) - VRmat(qb) * LᵀVᵀmat(qb) * VRᵀmat(qa) * LVᵀmat(qa)





using Rotations
using FiniteDiff
using Test

mech = Dojo.get_mechanism(:pendulum)
joint0 = mech.joints[1]
rot0 = joint0.rotational
rot0.axis_offset = rand(QuatRotation).q

xa = rand(3)
qa = rand(QuatRotation).q
xb = rand(3)
qb = rand(QuatRotation).q

p0 = rand(3)
J0 = Dojo.impulse_transform_jacobian(:parent, :parent, rot0, xa, qa, xb, qb, p0)
attjac = cat(I(3),Dojo.LVᵀmat(qa), dims=(1,2))
J1 = FiniteDiff.finite_difference_jacobian(
    z -> Dojo.impulse_transform(:parent, rot0, z[1:3], Quaternion(z[4:7]...,true), xb, qb) * p0,
    [xa; Dojo.vector(qa)]
    ) * attjac
@test norm(J0 - J1, Inf) < 1.0e-7

J0 = Dojo.impulse_transform_jacobian(:parent, :child, rot0, xa, qa, xb, qb, p0)
attjac = cat(I(3),Dojo.LVᵀmat(qb), dims=(1,2))
J1 = FiniteDiff.finite_difference_jacobian(
    z -> Dojo.impulse_transform(:parent, rot0, xa, qa, z[1:3], Quaternion(z[4:7]...,true)) * p0,
    [xb; Dojo.vector(qb)]
    ) * attjac
@test norm(J0 - J1, Inf) < 1.0e-7

J0 = Dojo.impulse_transform_jacobian(:child, :parent, rot0, xa, qa, xb, qb, p0)
attjac = cat(I(3),Dojo.LVᵀmat(qa), dims=(1,2))
J1 = FiniteDiff.finite_difference_jacobian(
    z -> Dojo.impulse_transform(:child, rot0, z[1:3], Quaternion(z[4:7]...,true), xb, qb) * p0,
    [xa; Dojo.vector(qa)]
    ) * attjac
@test norm(J0 - J1, Inf) < 1.0e-7

J0 = Dojo.impulse_transform_jacobian(:child, :child, rot0, xa, qa, xb, qb, p0)
attjac = cat(I(3),Dojo.LVᵀmat(qb), dims=(1,2))
J1 = FiniteDiff.finite_difference_jacobian(
    z -> Dojo.impulse_transform(:child, rot0, xa, qa, z[1:3], Quaternion(z[4:7]...,true)) * p0,
    [xb; Dojo.vector(qb)]
    ) * attjac
@test norm(J0 - J1, Inf) < 1.0e-7



rotation_matrix(inv(qb)) * rotation_matrix(qa) - rotation_matrix(inv(qb) * qa)

p0 = rand(3)
q0 = rand(QuatRotation).q
J0 = Dojo.∂rotation_matrix∂q(q0, p0)
J2 = Dojo.∂rotation_matrix∂q(q0, p0, attjac=true)
J1 = FiniteDiff.finite_difference_jacobian(q0 -> Dojo.rotation_matrix(Quaternion(q0...,true))*p0, Dojo.vector(q0))
J3 = J1 * Dojo.LVᵀmat(q0)
norm(J0 - J1, Inf)
norm(J2 - J3, Inf)

J4 = Dojo.∂rotation_matrix_inv∂q(q0, p0)
J6 = Dojo.∂rotation_matrix_inv∂q(q0, p0, attjac=true)
J5 = FiniteDiff.finite_difference_jacobian(q0 -> Dojo.rotation_matrix(inv(Quaternion(q0...,true)))*p0, Dojo.vector(q0))
J7 = J5 * Dojo.LVᵀmat(q0)
norm(J4 - J5, Inf)
norm(J6 - J7, Inf)



qo = Quaternion(1,0,0,0.)

qv = Vmat(inv(qo) * inv(qa) * qb)
Q = Vmat() * Lᵀmat(qo) * Lᵀmat(qa) * LVᵀmat(qb)



qvs = Vmat(inv(qb) * qa * qo)
Qs = Vmat() * Rmat(qo) * Rmat(qa) * Tmat() * LVᵀmat(qb)


x = rand(3)
qra = rand(4)
qrb = rand(4)
qra = Quaternion(qra ./ norm(qra)...)
qrb = Quaternion(qrb ./ norm(qrb)...)
vector_rotate(vector_rotate(x, qra),inv(qrb)) - VRᵀmat(inv(qrb) * qra) * LVᵀmat(inv(qrb) * qra) * x
VRᵀmat(qra) * LVᵀmat(qra) * x - vector_rotate(x, qra)
VLmat(qra) * RᵀVᵀmat(qra) * x - vector_rotate(x, qra)

qra = [1,0,0,1.]
qra = Quaternion(qra ./ norm(qra)..., true)
x = [1,0,0]
vector_rotate(x, qra)
VLmat(qra) * RᵀVᵀmat(qra) * x


VLmat(qb) * RᵀVᵀmat(qb) * x - vector_rotate(x, qb)
VRᵀmat(qb) * LVᵀmat(qb) * x - vector_rotate(x, qb)
VLmat(qb) * RᵀVᵀmat(qb) * x - vector_rotate(x, qb)
LVᵀmat(qrr) * LVᵀmat(qrr)'
VRᵀmat(qb)
Rᵀmat(qb)

x - VRᵀmat(qrr) * LVᵀmat(qrr) * x




VLmat(qb) * RᵀVᵀmat(qb)
qrr = rand(4)
qrr = [1,0,0,0.]
qrr = Quaternion(qrr ./ norm(qrr))
VLmat(qrr)
RᵀVᵀmat(qrr)



vector_rotate([1,0,0], qb)
Q * [1,0,0]


mech = Dojo.get_mechanism(:panda,
    timestep=0.05,
    gravity=-0.0,
    spring=0.0,
    damper=0.05)
# mech.joints[1].rotational.axis_offset = Quaternion(1,0,0,0.0,true)
mech.joints[1].rotational.axis_offset
function ctrl!(m,k)
    set_input!(m, 0.000 * 1 *sones(1))
    return nothing
end
input_dimension(mech)

# mech.joints[1].rotational.axis_offset = Quaternion(1,0,0,0.0)
# mech.bodies[1].mass = 3.0
zero_velocity!(mech)
y = [0.0,4]
set_minimal_state!(mech, y)

qa = Quaternions.QuaternionF64(1.0, 0.0, 0.0, 0.0, true)
qb = Quaternions.QuaternionF64(0.9988450542310338, 0.0, -4.705420204452237e-13, 0.0480474519428471, false)
angular_velocity(qa, qb, 0.05)

mech.joints[1]


storage = simulate!(mech, 5.0, Dojo.ctrl!, record=true)
visualize(mech, storage, vis=vis)
get_minimal_state(mech)
storage.ω[1]
plot([-ϕ[3] for ϕ in storage.ω[1]])
using Plots

joint = mech.joints[1]
body = mech.bodies[1]
pbody = get_body(mech, joint.parent_id)
cbody = get_body(mech, joint.child_id)
cbody
damper_impulses(mech, joint, body)
damper_impulses(:child, joint.rotational,
    get_body(mech, joint.parent_id),
    get_body(mech, joint.child_id),
    mech.timestep,
    unitary=false)
damper_force(:child, joint.rotational, current_configuration(pbody.state)[2], pbody.state.ϕsol[2],
    current_configuration(cbody.state)[2], cbody.state.ϕsol[2], 0.01, unitary=false)

function min_vel(qb)
    xa = SVector{3}([0.0, 0.0, 0.0])
    va = SVector{3}([0.0, 0.0, 0.0])
    qa = Quaternions.QuaternionF64(1.0, 0.0, 0.0, 0.0, true)
    ωa = SVector{3}([0.0, 0.0, 0.0])
    xb = SVector{3}([0.0, 0.0, 0.0])
    vb = SVector{3}([0.0, 0.0, 0.0])
    ωb = SVector{3}([0.0, 0.0, 1.0])
    return minimal_velocities(joint.rotational, xa, va, qa, ωa, xb, vb, qb, ωb, 0.05)
end

plot([min_vel(qb) for qb in storage.q[1]])

function get_damping(θ, ω)
    y = [θ, ω]
    set_minimal_state!(mech, y)
    imp = damper_impulses(mech, joint, body)
    # imp = damper_force(:child, joint.rotational, current_configuration(pbody.state)[2], pbody.state.ϕsol[2],
    #     current_configuration(cbody.state)[2], cbody.state.ϕsol[2], 0.01, unitary=false)
    return imp[6]
end
ys = [[2π*x,0] for x in 0:0.005:2]
zs = [minimal_to_maximal(mech, y) for y in ys]
storage = generate_storage(mech, zs)
visualize(mech, storage, vis=vis)

plot([get_damping(0.0, x) for x in 0.0:0.01:1.0])
plot([get_damping(2π*x, 1.0) for x in 0.0:0.01:2])

minimal_dimension(mech)

mech = get_npendulum(num_bodies=1, damper=-0.1)
initialize!(mech, :npendulum)
y = [0.5,4]
set_minimal_state!(mech, y)

storage = simulate!(mech, 3.3, record=true)
visualize(mech, storage, vis=vis)
get_minimal_state(mech)
