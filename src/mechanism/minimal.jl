function minimal_to_maximal(mechanism::Mechanism{T,Nn,Ne,Nb,Ni}, x::AbstractVector{Tx}) where {T,Nn,Ne,Nb,Ni,Tx}
	# When we set the Δv and Δω in the mechanical graph, we need to start from t#he root and get down to the leaves.
	# Thus go through the joints in order, start from joint between robot and origin and go down the tree.
	off = 0
	for id in reverse(mechanism.system.dfs_list)
		(id > Ne) && continue # only treat joints
		joint = mechanism.joints[id]
		nu = control_dimension(joint)
		set_minimal_coordinates_velocities!(mechanism, joint, xmin=x[off .+ SUnitRange(1, 2nu)])
		off += 2nu
	end
	z = get_maximal_state(mechanism)
	return z
end

function minimal_to_maximal_jacobian_analytical(mechanism::Mechanism{T,Nn,Ne,Nb,Ni}, x::AbstractVector{Tx}) where {T,Nn,Ne,Nb,Ni,Tx}
	J = zeros(maximal_dimension(mechanism), minimal_dimension(mechanism))
	z = minimal_to_maximal(mechanism, x)
	off = 0
	for id in reverse(mechanism.system.dfs_list)
		(id > Ne) && continue # only treat joints
		joint = mechanism.joints[id]
		nu = control_dimension(joint)
		idx = collect(off .+ (1:(2nu)))

		J[:, idx] = position_velocity_jacobian(mechanism, joint, z, x[idx])

		off += 2nu
	end

	return J
end

### Support for FD ###

function position_velocity_jacobian(mechanism::Mechanism{T,Nn,Ne,Nb,Ni}, joint, z, x) where {T,Nn,Ne,Nb,Ni}
	child_joints = unique([get_node(mechanism, id) for id in recursivedirectchildren!(mechanism.system, joint.id) if get_node(mechanism, id) isa JointConstraint])
	cv = minimal_coordinates_velocities(mechanism)

	# initialize
	G = zeros(maximal_dimension(mechanism), 2 * control_dimension(joint))

	# root 
	if joint.parent_id == 0 
		xp, vp, qp, ϕp = current_configuration_velocity(mechanism.origin.state)
		zp = [xp; vp; vector(qp); ϕp] 
	else 
		zp = z[(joint.parent_id - Ne - 1) * 13 .+ (1:13)]
	end

	∂z∂θ = position_velocity_jacobian_minimal(mechanism, joint, zp, x)
	G[(joint.child_id - Ne - 1) * 13 .+ (1:13), :] = ∂z∂θ

	# recursion
	∂z∂z = Dict()
	∂a∂z = Dict() 
	push!(∂a∂z, "$(joint.child_id)" => ∂z∂θ)

	for node in child_joints
		haskey(∂a∂z, "$(node.child_id)") && continue
		if node.name == :origin 
			xp, vp, qp, ϕp = current_configuration_velocity(mechanism.origin.state)
			zp = [xp; vp; vector(qp); ϕp] 
		else 
			zp = z[(node.parent_id - Ne - 1) * 13 .+ (1:13)]
		end

		d = position_velocity_jacobian_maximal(mechanism, node, zp, cv[node.id])
		push!(∂z∂z, "$(node.child_id)_$(node.parent_id)" => d)
		push!(∂a∂z, "$(node.child_id)" => d * ∂a∂z["$(node.parent_id)"])

		G[(node.child_id - Ne - 1) * 13 .+ (1:13), :] = ∂a∂z["$(node.child_id)"]
	end
	return G
end

function joint_position_velocity(mechanism, joint, z, x) 
	mechanism = deepcopy(mechanism)
    body_parent = get_body(mechanism, joint.parent_id)

    if body_parent.name != :origin
		xp = z[1:3] 
		vp = z[4:6]
		qp = UnitQuaternion(z[7:10]..., false)
		ϕp = z[11:13]
        set_position!(body_parent, x=xp, q=qp)
        set_velocity!(body_parent, v=vp, ω=ϕp)
    end

    set_minimal_coordinates_velocities!(mechanism, joint, xmin=x)
    xc, vc, qc, ωc = initial_configuration_velocity(get_body(mechanism, joint.child_id).state)
    [xc; vc; vector(qc); ωc]
end

function position_velocity_jacobian_minimal(mechanism, joint, z, x)
    FiniteDiff.finite_difference_jacobian(y -> joint_position_velocity(mechanism, joint, z, y), x) 
end

function position_velocity_jacobian_maximal(mechanism, joint, z, x)
    FiniteDiff.finite_difference_jacobian(y -> joint_position_velocity(mechanism, joint, y, x), z) 
end

##########

function minimal_to_maximal_jacobian(mechanism::Mechanism, x)
	FiniteDiff.finite_difference_jacobian(y -> minimal_to_maximal(mechanism, y), x)
end

function get_minimal_gradients(mechanism::Mechanism{T}, z::AbstractVector{T}, u::AbstractVector{T};
	opts=SolverOptions()) where T
	# simulate next state
	step!(mechanism, z, u, opts=opts)
	# current maximal state
	z = get_state(mechanism)
	# next maximal state
	z_next = get_next_state(mechanism)
	# current minimal state
	x = maximal_to_minimal(mechanism, z)
	# maximal dynamics Jacobians
	maximal_jacobian_state, minimal_jacobian_control = get_maximal_gradients(mechanism)
	# minimal to maximal Jacobian at current time step (rhs)
	min_to_max_jacobian_current = minimal_to_maximal_jacobian(mechanism, x)
	# maximal to minimal Jacobian at next time step (lhs)
	max_to_min_jacobian_next = maximal_to_minimal_jacobian(mechanism, z_next)
	# minimal state Jacobian
	minimal_jacobian_state = max_to_min_jacobian_next * maximal_jacobian_state * min_to_max_jacobian_current
	# minimal control Jacobian
	minimal_jacobian_control = max_to_min_jacobian_next * minimal_jacobian_control

	return minimal_jacobian_state, minimal_jacobian_control
end

function get_minimal_state(mechanism::Mechanism{T,Nn,Ne,Nb,Ni};
	pos_noise=nothing, vel_noise=nothing,
	pos_noise_range=[-Inf, Inf], vel_noise_range=[-3.9 / mechanism.timestep^2, 3.9 / mechanism.timestep^2]) where {T,Nn,Ne,Nb,Ni}
	x = []
	# When we set the Δv and Δω in the mechanical graph, we need to start from the root and get down to the leaves.
	# Thus go through the joints in order, start from joint between robot and origin and go down the tree.
	for id in reverse(mechanism.system.dfs_list)
		(id > Ne) && continue # only treat joints
		joint = mechanism.joints[id]
		c = zeros(T,0)
		v = zeros(T,0)
		pbody = get_body(mechanism, joint.parent_id)
		cbody = get_body(mechanism, joint.child_id)
		for (i, element) in enumerate(joint.constraints)
			pos = minimal_coordinates(element, pbody, cbody)
			vel = minimal_velocities(element, pbody, cbody)
			if pos_noise != nothing
				pos += clamp.(length(pos) == 1 ? rand(pos_noise, length(pos))[1] : rand(pos_noise, length(pos)), pos_noise_range...)
			end
			if vel_noise != nothing
				vel += clamp.(length(vel) == 1 ? rand(vel_noise, length(vel))[1] : rand(vel_noise, length(vel)), vel_noise_range...)
			end
			push!(c, pos...)
			push!(v, vel...)
		end
		push!(x, [c; v]...)
	end
	x = [x...]
	return x
end