function getsphere(; timestep::T=0.01, g::T=-9.81, cf::T=0.8, radius=0.5,
        contact::Bool=true, contact_type::Symbol=:contact) where T
    origin = Origin{T}(name=:origin)
    mass = 1.0
    bodies = [Sphere(radius, mass, name=:sphere)]
    joints = [JointConstraint(Floating(origin, bodies[1]), name = :floating_joint)]
    mechanism = Mechanism(origin, bodies, joints, timestep = timestep, g = g)

    if contact
        contact = [0,0,0.0]
        normal = [0,0,1.0]
        contacts = [contact_constraint(get_body(mechanism, :sphere), normal, cf=cf,
            p=contact, offset=[0,0,radius], contact_type=contact_type)]
        set_position(mechanism, get_joint_constraint(mechanism, :floating_joint), [0;0;radius;zeros(3)])
        mechanism = Mechanism(origin, bodies, joints, contacts, g=g, timestep=timestep)
    end
    return mechanism
end

function initializesphere!(mechanism::Mechanism; x::AbstractVector{T}=zeros(3),
        q::UnitQuaternion{T}=one(UnitQuaternion), v::AbstractVector{T}=zeros(3),
        ω::AbstractVector{T}=zeros(3)) where T
    r = collect(mechanism.bodies)[1].shape.r
    joint = get_joint_constraint(mechanism, :floating_joint)
    zeroVelocity!(mechanism)
    set_position(mechanism, joint, [x+[0,0,r] rotation_vector(q)])
    set_velocity!(mechanism, joint, [v; ω])
end
