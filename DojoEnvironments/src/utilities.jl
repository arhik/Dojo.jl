################################################################################
# Visuals
################################################################################
function visualize(env::Environment, traj::Vector{Vector{T}}; build::Bool=true) where T
	@assert size(traj[1]) == size(env.state)
    storage = generate_storage(env.mechanism, [env.representation == :minimal ? minimal_to_maximal(env.mechanism, x) : x for x in traj])
    Dojo.visualize(env.mechanism, storage, vis=env.vis, build=build)
end

################################################################################
# Miscellaneous
################################################################################
type2symbol(H) = Symbol(lowercase(String(H.name.name)))

function get_control_mask(n_inputs, indices)
    n_outputs = length(indices)
    m = zeros(n_outputs, n_inputs)
    for (i,ind) in enumerate(indices)
        m[i,ind] = 1.0
    end
    return m
end

function set_springs!(joints, spring::Real)
    if spring > 0
        for joint in joints[2:end]
            joint.spring = true
            joint.translational.spring=spring
            joint.rotational.spring=spring
        end
    end
end

function set_springs!(joints, springs::AbstractArray)
    for (i,spring) in enumerate(springs)
        if spring > 0
            joints[i+1].spring = true
            joints[i+1].translational.spring=spring
            joints[i+1].rotational.spring=spring
        end
    end
end

function set_dampers!(joints, damper::Real)
    if damper > 0
        for joint in joints[2:end]
            joint.damper = true
            joint.translational.damper=damper
            joint.rotational.damper=damper
        end
    end
end

function set_dampers!(joints, dampers::AbstractArray)
    for (i,damper) in enumerate(dampers)
        if damper > 0
            joints[i+1].damper = true
            joints[i+1].translational.damper=damper
            joints[i+1].rotational.damper=damper
        end
    end
end