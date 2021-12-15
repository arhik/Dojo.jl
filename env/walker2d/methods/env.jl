################################################################################
# Walker2d
################################################################################
struct Walker2d end

function walker2d(; mode::Symbol=:min, dt::T=0.05, g::T=-9.81,
    cf::T=1.9, spring=0.0, damper=0.1,
    s::Int=1, contact::Bool=true, info=nothing, vis::Visualizer=Visualizer(),
    opts_step=InteriorPointOptions(), opts_grad=InteriorPointOptions()) where T

    mechanism = getwalker2d(Δt=dt, g=g, cf=cf, spring=spring, damper=damper, contact=contact)
    initializewalker2d!(mechanism)

    if mode == :min
        nx = minCoordDim(mechanism)
    elseif mode == :max
        nx = maxCoordDim(mechanism)
    end
    nu = 6
    no = nx

    # values taken from Mujoco's model, combining the control range -1, 1 and the motor gears.
    aspace = BoxSpace(nu, low=(-ones(nu)), high=(ones(nu)))
    ospace = BoxSpace(no, low=(-Inf * ones(no)), high=(Inf * ones(no)))

    rng = MersenneTwister(s)

    z = getMaxState(mechanism)
    x = mode == :min ? max2min(mechanism, z) : z

    fx = zeros(nx, nx)
    fu = zeros(nx, nu)

    u_prev = zeros(nu)
    control_mask = [zeros(nu, 3) I(nu)]
    motor_gear = [100, 100, 100, 100, 100, 100.]
    control_scaling = Diagonal(dt * motor_gear)

    build_robot(vis, mechanism)

    TYPES = [Walker2d, T, typeof(mechanism), typeof(aspace), typeof(ospace), typeof(info)]
    env = Environment{TYPES...}(mechanism, mode, aspace, ospace,
        x, fx, fu,
        u_prev, control_mask, control_scaling,
        nx, nu, no,
        info,
        [rng], vis,
        opts_step, opts_grad)

    return env
end

function reset(env::Environment{Walker2d}; x=nothing, reset_noise_scale = 0.1)
    if x != nothing
        env.x .= x
    else
        # initialize above the ground to make sure that with random initialization we do not violate the ground constraint.
        initialize!(env.mechanism, :walker2d, z = 0.25)
        x0 = getMinState(env.mechanism)
        nx = minCoordDim(env.mechanism)
        nz = maxCoordDim(env.mechanism)

        low = -reset_noise_scale
        high = reset_noise_scale
        x = x0 + (high - low) .* rand(env.rng[1], nx) .+ low # we ignored the normal distribution on the velocities
        z = min2max(env.mechanism, x)
        setState!(env.mechanism, z)
        if env.mode == :min
            env.x .= getMinState(env.mechanism)
        elseif env.mode == :max
            env.x .= getMaxState(env.mechanism)
        end
        env.u_prev .= 0.0
    end
    return _get_obs(env)
end

function cost(env::Environment{Walker2d}, x, u;
        forward_reward_weight = 1.0, ctrl_cost_weight = 0.1)

    if env.mode == :min
        x_velocity = -x[5]
    else
        i_torso = findfirst(body -> body.name == "torso", collect(env.mechanism.bodies))
        z_torso = x[(i_torso-1)*13 .+ (1:13)]
        x_velocity = z_torso[4]
    end
    # @show mean(abs.(u))
    c = ctrl_cost_weight * u'*u - x_velocity * forward_reward_weight
    return c
end