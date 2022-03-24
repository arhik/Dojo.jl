function get_halfcheetah(; 
    timestep=0.01, 
    gravity=[0.0; 0.0; -9.81], 
    friction_coefficient=0.4,
    contact_feet=true,
    contact_body=true,
    limits=true,
    spring=[240.0, 180.0, 120.0, 180.0, 120.0, 60.0],
    damper=[6.0, 4.5, 3.0, 4.5, 3.0, 1.5],
    joint_limits=[[-0.52, -0.785, -0.400, -1.0, -1.20, -0.5],
                  [ 1.05,  0.785,  0.785,  0.7,  0.87,  0.5]],
    T=Float64)
    
    path = joinpath(@__DIR__, "../deps/halfcheetah.urdf")
    mech = Mechanism(path, false, T, 
        gravity=gravity, 
        timestep=timestep, 
        spring=spring, 
        damper=damper)

    # joint limits
    joints = deepcopy(mech.joints)

    if limits
        bthigh = get_joint(mech, :bthigh)
        joints[bthigh.id] = add_limits(mech, bthigh, 
            rot_limits=[SVector{1}(joint_limits[1][1]), SVector{1}(joint_limits[2][1])])

        bshin = get_joint(mech, :bshin)
        joints[bshin.id] = add_limits(mech, bshin, 
            rot_limits=[SVector{1}(joint_limits[1][2]), SVector{1}(joint_limits[2][2])])

        bfoot = get_joint(mech, :bfoot)
        joints[bfoot.id] = add_limits(mech, bfoot, 
            rot_limits=[SVector{1}(joint_limits[1][3]), SVector{1}(joint_limits[2][3])])

        fthigh = get_joint(mech, :fthigh)
        joints[fthigh.id] = add_limits(mech, fthigh, 
            rot_limits=[SVector{1}(joint_limits[1][4]), SVector{1}(joint_limits[2][4])])

        fshin = get_joint(mech, :fshin)
        joints[fshin.id] = add_limits(mech, fshin, 
            rot_limits=[SVector{1}(joint_limits[1][5]), SVector{1}(joint_limits[2][5])])

        ffoot = get_joint(mech, :ffoot)
        joints[ffoot.id] = add_limits(mech, ffoot, 
            rot_limits=[SVector{1}(joint_limits[1][6]), SVector{1}(joint_limits[2][6])])

        mech = Mechanism(Origin{T}(), [mech.bodies...], [joints...], 
            gravity=gravity, 
            timestep=timestep, 
            spring=spring, 
            damper=damper)
    end

    if contact_feet
        origin = Origin{T}()
        bodies = mech.bodies
        joints = mech.joints

        normal = [0.0; 0.0; 1.0]
        names = contact_body ? getfield.(mech.bodies, :name) : [:ffoot, :bfoot]
        models = []
        for name in names
            body = get_body(mech, name)
            if name == :torso # need special case for torso
                # torso
                pf = [+0.5 * body.shape.shape[1].rh[2]; 0.0; 0.0]
                pb = [-0.5 * body.shape.shape[1].rh[2]; 0.0; 0.0]
                o = body.shape.shape[1].rh[1]
                push!(models, contact_constraint(body, normal, 
                    friction_coefficient=friction_coefficient, 
                    contact_origin=pf, 
                    contact_radius=o))
                push!(models, contact_constraint(body, normal, 
                    friction_coefficient=friction_coefficient, 
                    contact_origin=pb, contact_radius=o))

                # head
                pf = [+0.5 * body.shape.shape[1].rh[2] + 0.214; 0.0; 0.1935]
                o = body.shape.shape[2].rh[1]
                push!(models, contact_constraint(body, normal, 
                    friction_coefficient=friction_coefficient, 
                    contact_origin=pf, 
                    contact_radius=o))
            else
                p = [0;0; -0.5 * body.shape.rh[2]]
                o = body.shape.rh[1]
                push!(models, contact_constraint(body, normal, 
                    friction_coefficient=friction_coefficient, 
                    contact_origin=p, 
                    contact_radius=o))
            end
        end
        set_minimal_coordinates!(mech, get_joint(mech, :floating_joint), [0.576509, 0.0, 0.02792])
        mech = Mechanism(origin, bodies, joints, [models...], 
            gravity=gravity, 
            timestep=timestep, 
            spring=spring, 
            damper=damper)
    end
    return mech
end

function initialize_halfcheetah!(mechanism::Mechanism{T}; 
    body_position=[0.0, 0.0],  
    body_orientation=0.0) where T

    set_minimal_coordinates!(mechanism,
                 get_joint(mechanism, :floating_joint),
                 [body_position[2] + 0.576509, -body_position[1], -body_orientation + 0.02792])
    for joint in mechanism.joints
        (joint.name != :floating_joint) && set_minimal_coordinates!(mechanism, joint, zeros(input_dimension(joint)))
    end
    zero_velocity!(mechanism)
end
