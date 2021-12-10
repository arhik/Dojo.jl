function getsnake(; Δt::T = 0.01, g::T = -9.81, cf::T = 0.8, contact::Bool = true,
    conetype = :soc, spring = 0.0, damper = 0.0, Nlink::Int = 2, jointtype::Symbol = :Spherical, h::T = 1.0, r::T = 0.05) where {T}

    # Parameters
    ex = [1.;0.;0.]
    ey = [0.;1.;0.]
    ez = [0.;0.;1.]

    vert11 = [0.;0.;h / 2]
    vert12 = -vert11

    # Links
    origin = Origin{T}()
    # links = [Cylinder(r, h, h, color = RGBA(1., 0., 0.)) for i = 1:Nlink]
    links = [Box(3r, 2r, h, h, color = RGBA(1., 0., 0.)) for i = 1:Nlink]
    # links = [Box(h, h, h, h, color = RGBA(1., 0., 0.)) for i = 1:Nlink]

    # Constraints
    jointb1 = EqualityConstraint(Floating(origin, links[1], spring = 0.0, damper = 0.0)) # TODO remove the spring and damper from floating base
    if Nlink > 1
        eqcs = [EqualityConstraint(Prototype(jointtype, links[i - 1], links[i], ex; p1 = vert12, p2 = vert11, spring = spring, damper = damper)) for i = 2:Nlink]
        # eqcs = [EqualityConstraint(Prototype(jointtype, links[i - 1], links[i], ez; p1 = vert12, p2 = vert11, spring = spring, damper = damper)) for i = 2:Nlink]
        eqcs = [jointb1; eqcs]
    else
        eqcs = [jointb1]
    end

    if contact
        n = Nlink
        normal = [[0;0;1.0] for i = 1:n]
        cf = cf * ones(n)

        if conetype == :soc
            contineqcs1 = contactconstraint(links, normal, cf, p = fill(vert11, n)) # we need to duplicate point for prismatic joint for instance
            contineqcs2 = contactconstraint(links, normal, cf, p = fill(vert12, n))
            mech = Mechanism(origin, links, eqcs, [contineqcs1; contineqcs2], g = g, Δt = Δt, spring=spring, damper=damper)

        elseif conetype == :linear
            @error "linear contact not implemented"
        else
            error("Unknown conetype")
        end
    else
        mech = Mechanism(origin, links, eqcs, g = g, Δt = Δt, spring=spring, damper=damper)
    end
    return mech
end

function initializesnake!(mechanism::Mechanism{T,Nn,Ne,Nb}; x::AbstractVector{T} = [0,-0.5,0],
    v::AbstractVector{T} = zeros(3), ω::AbstractVector{T} = zeros(3),
    Δω::AbstractVector{T} = zeros(3), Δv::AbstractVector{T} = zeros(3),
    q1::UnitQuaternion{T} = UnitQuaternion(RotX(0.6 * π))) where {T,Nn,Ne,Nb}

    bodies = collect(mechanism.bodies)
    link1 = bodies[1]
    # h = link1.shape.rh[2]
    h = link1.shape.xyz[3]
    vert11 = [0.;0.; h/2]
    vert12 = -vert11
    # set position and velocities
    setPosition!(mechanism.origin, link1, p2 = x, Δq = q1)
    setVelocity!(link1, v = v, ω = ω)

    previd = link1.id
    for (i,body) in enumerate(Iterators.drop(mechanism.bodies, 1))
        setPosition!(getbody(mechanism, previd), body, p1 = vert12, p2 = vert11)
        setVelocity!(getbody(mechanism, previd), body, p1 = vert12, p2 = vert11,
                Δv = Δv, Δω = Δω)
        previd = body.id
    end
end