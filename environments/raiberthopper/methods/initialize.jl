function get_raiberthopper(; 
    timestep=0.05, 
    gravity=[0.0; 0.0; -9.81], 
    spring=0.0, 
    damper=0.1, 
    contact_foot=true, 
    contact_body=true,
    T=Float64)
    #TODO: make customizable

    # Parameters
    leg_axis = [0.0; 0.0; 1.0]
    leg_length_nominal = 0.5
    body_radius = 0.1
    foot_radius = 0.05
    body_mass = 4.18 # from MuJoCo model 
    foot_mass = 0.52 # from MuJoCo model

    # Links
    origin = Origin{Float64}()
    body = Sphere(body_radius, body_mass)
    foot = Sphere(foot_radius, foot_mass)
    links = [body, foot]

    # Joint Constraints
    joint_origin_body = JointConstraint(Floating(origin, body))
    joint_body_foot = JointConstraint(Prismatic(body, foot, leg_axis;
        parent_vertex=szeros(Float64, 3), 
        child_vertex=szeros(Float64, 3), 
        spring=spring, 
        damper=damper))
    joints = [joint_origin_body, joint_body_foot]

    # Mechanism
    if contact_foot
         # Contact
        contact_normal = [0.0; 0.0; 1.0]
        friction_coefficient = 0.5

        # foot
        foot_contacts = contact_constraint(foot, contact_normal, 
            friction_coefficient=friction_coefficient,
            contact_point=[0.0; 0.0; 0.0], 
            offset=[0.0; 0.0; 
            foot_radius])

        contacts = [foot_contacts]

        # body
        if contact_body
            body_contacts = contact_constraint(body, contact_normal, 
                friction_coefficient=friction_coefficient,
                contact_point=[0.0; 0.0; 0.0], 
                offset=[0.0; 0.0; body_radius])
            push!(contacts, body_contacts)
        end
        
        mech = Mechanism(origin, links, joints, contacts, 
            gravity=gravity, 
            timestep=timestep, 
            spring=spring, 
            damper=damper)
    else
        mech = Mechanism(origin, links, joints, 
            gravity=gravity, 
            timestep=timestep, 
            spring=spring, 
            damper=damper)
    end
    return mech
end

function initialize_raiberthopper!(mech::Mechanism{T,Nn,Ne,Nb}; 
    body_position=[0.0, 0.0, 0.05],
    leg_length=0.5, 
    body_linear_velocity=zeros(3), 
    body_angular_velocity=zeros(3)) where {T,Nn,Ne,Nb}

    pbody = mech.bodies[1]
    cbody = mech.bodies[2]
    joint2 = mech.joints[2]
    tra2 = joint2.translational

    # origin to body
    set_maximal_configurations!(mech.origin, pbody, 
        Δx=[body_position[1:2]; leg_length + body_position[3]])
    set_maximal_velocities!(pbody, 
        v=body_linear_velocity, 
        ω=body_angular_velocity)

    # body to foot
    set_maximal_configurations!(pbody, cbody, 
        Δx=[0.0; 0.0; -leg_length], 
        Δq=RotX(0.0))
    set_maximal_velocities!(pbody, cbody, 
        parent_vertex=tra2.vertices[1], 
        child_vertex=tra2.vertices[2], 
        Δv=zeros(3), 
        Δω=zeros(3))
end
