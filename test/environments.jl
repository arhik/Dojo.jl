environments = [
    :ant, 
    :atlas,
    :cartpole,
    :halfcheetah,
    :hopper, 
    :pendulum,
    :quadruped,
    :raiberthopper,
    :rexhopper,
    :walker,
    :block
]

throw_envs = [
    :hopper,
    :rexhopper,
    :walker,
]

@testset "$name" for name in environments 
    env = get_environment(name)
    if !(name in throw_envs)
        @test size(reset(env)) == (env.observation_space.n,)
        o, r, d, i = step(env, Dojo.sample(env.input_space))
        @test size(o) == (env.observation_space.n,)
    end
end 
