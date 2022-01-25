@inline getbody(mechanism::Mechanism{T,Nn,Ne,Nb,Ni}, id::Integer) where {T,Nn,Ne,Nb,Ni} = collect(mechanism.bodies)[id-Ne]
@inline getbody(mechanism::Mechanism, id::Nothing) = mechanism.origin

function getbody(mechanism::Mechanism, name::Symbol)
    if name == :origin
        return mechanism.origin
    else
        for body in mechanism.bodies
            if body.name == name
                return body
            end
        end
    end
    return
end

@inline geteqconstraint(mechanism::Mechanism, id::Integer) = mechanism.eqconstraints[id]

function geteqconstraint(mechanism::Mechanism, name::Symbol)
    for eqc in mechanism.eqconstraints
        if eqc.name == name
            return eqc
        end
    end
    return
end

@inline getineqconstraint(mechanism::Mechanism{T,Nn,Ne,Nb,Ni}, id::Integer) where {T,Nn,Ne,Nb,Ni} = mechanism.ineqconstraints[id-Ne-Nb]
function getineqconstraint(mechanism::Mechanism, name::Symbol)
    for ineqc in mechanism.ineqconstraints
        if ineqc.name == name
            return ineqc
        end
    end
    return
end

function getnode(mechanism::Mechanism{T,Nn,Ne,Nb}, id::Integer) where {T,Nn,Ne,Nb}
    if id <= Ne
        return geteqconstraint(mechanism, id)
    elseif id <= Ne+Nb
        return getbody(mechanism, id)
    else
        return getineqconstraint(mechanism, id)
    end
end
getnode(mechanism::Mechanism, id::Nothing) = mechanism.origin

function getnode(mechanism::Mechanism, name::Symbol)
    node = getbody(mechanism,name)
    if node === nothing
        node = geteqconstraint(mechanism,name)
    end
    if node === nothing
        node = getineqconstraint(mechanism,name)
    end
    return node
end

@inline function discretizestate!(mechanism::Mechanism)
    for body in mechanism.bodies 
        discretizestate!(body, mechanism.Δt) 
    end
    return
end

@inline function ∂gab∂ʳba(mechanism::Mechanism{T,Nn,Ne,Nb,Ni}, body1::Body, body2::Body) where {T,Nn,Ne,Nb,Ni}
    Δt = mechanism.Δt
    _, _, q1, ω1 = fullargssol(body1.state)
    _, _, q2, ω2 = fullargssol(body2.state)

    x1, q1 = posargs3(body1.state, Δt)
    x2, q2 = posargs3(body2.state, Δt)

    dGab = szeros(6,6)
    dGba = szeros(6,6)

    for connectionid in connections(mechanism.system, body1.id)
        !(connectionid <= Ne) && continue # body
        eqc = getnode(mechanism, connectionid)
        Nc = length(eqc.childids)
        off = 0
        if body1.id == eqc.parentid
            for i in 1:Nc
                joint = eqc.constraints[i]
                Nj = length(joint)
                if body2.id == eqc.childids[i]
                    Aᵀ = zerodimstaticadjoint(constraintmat(joint))
                    eqc.isspring && (dGab -= ∂springforcea∂velb(joint, body1, body2, Δt)) #should be useless
                    eqc.isdamper && (dGab -= ∂damperforcea∂velb(joint, body1, body2, Δt))
                    eqc.isspring && (dGba -= ∂springforceb∂vela(joint, body1, body2, Δt)) #should be useless
                    eqc.isdamper && (dGba -= ∂damperforceb∂vela(joint, body1, body2, Δt))
                end
                off += Nj
            end
        elseif body2.id == eqc.parentid
            for i = 1:Nc
                joint = eqc.constraints[i]
                Nj = length(joint)
                if body1.id == eqc.childids[i]
                    Aᵀ = zerodimstaticadjoint(constraintmat(joint))
                    # eqc.isspring && (dGab -= ∂springforcea∂velb(joint, body2, body1, Δt)) #should be useless
                    eqc.isdamper && (dGab -= ∂damperforcea∂velb(joint, body2, body1, Δt))
                    # eqc.isspring && (dGba -= ∂springforceb∂vela(joint, body2, body1, Δt)) #should be useless
                    eqc.isdamper && (dGba -= ∂damperforceb∂vela(joint, body2, body1, Δt))
                end
                off += Nj
            end
        end
    end
    return dGab, dGba
end
