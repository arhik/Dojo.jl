################################################################################
# Dimension
################################################################################

# Mechanism
data_dim(mechanism::Mechanism; attjac::Bool=true) =
	sum(Vector{Int64}(data_dim.(mechanism.joints))) +
    sum(Vector{Int64}(data_dim.(mechanism.bodies, attjac=attjac))) +
	sum(Vector{Int64}(data_dim.(mechanism.contacts)))

# Joints
data_dim(joint::JointConstraint) = 2 + sum(data_dim.([joint.translational, joint.rotational])) # [utra, urot, spring, damper]
data_dim(joint::Translational{T,Nλ,Nb,N,Nb½,N̄λ}) where {T,Nλ,Nb,N,Nb½,N̄λ} = N̄λ # [utra]
data_dim(joint::Rotational{T,Nλ,Nb,N,Nb½,N̄λ}) where {T,Nλ,Nb,N,Nb½,N̄λ} = N̄λ # [urot]

# Body
data_dim(body::Body; attjac::Bool=true) = attjac ? 19 : 20 # 1+6+6+6 or 1+6+6+7 [m,flat(J),v15,ϕ15,x2,q2] with attjac

# Contact
data_dim(contact::ContactConstraint) = data_dim(contact.model)
data_dim(model::NonlinearContact) = 5 # [friction_coefficient, contact_radius, p]
data_dim(model::LinearContact) = 5 # [friction_coefficient, contact_radius, p]
data_dim(model::ImpactContact) = 4 # [contact_radius, p]
data_dim(model::SoftContact) = 4 # [contact_radius, p]


################################################################################
# Attitude Jacobian
################################################################################

# Mechanism
function data_attitude_jacobian(mechanism::Mechanism)
	attjacs = [data_attitude_jacobian.(mechanism.joints);
		data_attitude_jacobian.(mechanism.bodies);
		data_attitude_jacobian.(mechanism.contacts)]
	attjac = cat(attjacs..., dims=(1,2))
	return attjac
end

# Joints
function data_attitude_jacobian(joint::JointConstraint)
	return I(data_dim(joint))
end

# Body
function data_attitude_jacobian(body::Body)
	# [m,flat(J),x1,q1,x2,q2]
	x2, q2 = current_configuration(body.state)
	attjac = cat(I(1+6+6+3), LVᵀmat(q2), dims=(1,2))
	return attjac
end

# Contacts
function data_attitude_jacobian(contact::ContactConstraint)
	return I(data_dim(contact))
end

################################################################################
# Get Data
################################################################################

# Mechanism
get_data(mechanism::Mechanism) = vcat([get_data.(mechanism.joints);
	get_data.(mechanism.bodies); get_data.(mechanism.contacts)]...)

# Joints
function get_data(joint::JointConstraint)
	joints = [joint.translational, joint.rotational]
	u = vcat(nullspace_mask.(joints) .* getfield.(joints, :input)...)
	spring = joints[1].spring # assumes we have the same spring and dampers for translational and rotational joint.
	damper = joints[1].damper # assumes we have the same spring and dampers for translational and rotational joint.
	return [u; spring; damper]
end

# Body
function get_data(body::Body)
	m = body.mass
	j = flatten_inertia(body.inertia)
	v15 = body.state.v15
	ϕ15 = body.state.ϕ15
	x2, q2 = current_configuration(body.state)
	return [m; j; v15; ϕ15; x2; vector(q2)]
end

# Contacts
get_data(model::NonlinearContact) = [model.friction_coefficient; model.collision.contact_radius; model.collision.contact_origin]
get_data(model::LinearContact) = [model.friction_coefficient; model.collision.contact_radius; model.collision.contact_origin]
get_data(model::ImpactContact) = [model.collision.contact_radius; model.collision.contact_origin]
get_data(contact::ContactConstraint) = get_data(contact.model)


################################################################################
# Set Data
################################################################################

# Mechanism
function set_data!(mechanism::Mechanism, data::AbstractVector)
	# It's important to treat bodies before eqcs
	# set_data!(body) will erase state.F2 and state.τ2
	# set_data!(eqc) using applyinput!, will write in state.F2 and state.τ2
	c = 0
	for joint in mechanism.joints
		Nd = data_dim(joint)
		set_data!(joint, data[c .+ (1:Nd)]); c += Nd
	end
	for body in mechanism.bodies
		Nd = data_dim(body, attjac=false)
		set_data!(body, data[c .+ (1:Nd)], mechanism.timestep); c += Nd
	end
	for contact in mechanism.contacts
		Nd = data_dim(contact)
		set_data!(contact, data[c .+ (1:Nd)]); c += Nd
	end
	for joint in mechanism.joints
		input_impulse!(joint, mechanism, false)
	end
	return nothing
end

# Joints
function set_data!(joint::JointConstraint, data::AbstractVector)
	nu = input_dimension(joint)
	u = data[SUnitRange(1,nu)]
	spring = data[nu+1]
	damper = data[nu+2]

	set_input!(joint, u)
	for joint in [joint.translational, joint.rotational]
		joint.spring=spring
		joint.damper=damper
	end
	return nothing
end

# Body
function set_data!(body::Body, data::AbstractVector, timestep)
	# [m,flat(J),x2,v15,q2,ϕ15]
	m = data[1]
	J = lift_inertia(data[SUnitRange(2,7)])
	v15 = data[SUnitRange(8,10)]
	ϕ15 = data[SUnitRange(11,13)]
	x2 = data[SUnitRange(14,16)]
	q2 = Quaternion(data[17:20]...)
	x1 = next_position(x2, -v15, timestep)
	q1 = next_orientation(q2, -ϕ15, timestep)

	body.mass = m
	body.inertia = J
	body.state.x1 = x1
	body.state.v15 = v15
	body.state.q1 = q1
	body.state.ϕ15 = ϕ15
	body.state.x2 = x2
	body.state.q2 = q2
	body.state.F2 = SVector{3}(0,0,0.)
	body.state.τ2 = SVector{3}(0,0,0.)
	return nothing
end

# Contact
function set_data!(model::NonlinearContact, data::AbstractVector)
	model.friction_coefficient = data[1]
    model.collision.contact_radius = data[2]
    model.collision.contact_origin = data[SVector{3,Int}(3:5)]
    return nothing
end

function set_data!(model::LinearContact, data::AbstractVector)
	model.friction_coefficient = data[1]
    model.collision.contact_radius = data[2]
    model.collision.contact_origin = data[SVector{3,Int}(3:5)]
    return nothing
end

function set_data!(model::ImpactContact, data::AbstractVector)
    model.collision.contact_radius = data[1]
    model.collision.contact_origin = data[SVector{3,Int}(2:4)]
    return nothing
end

function set_data!(contact::ContactConstraint, data::AbstractVector)
	model = contact.model
	N = data_dim(model)
	set_data!(model, data[1:N])
    return nothing
end
