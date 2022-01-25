abstract type Joint{T,Nλ,Nb,N} end

## General functions
getT(joint::Joint{T}) where T = T
Base.length(joint::Joint{T,Nλ}) where {T,Nλ} = Nλ
Base.zero(joint::Joint{T,Nλ}) where {T,Nλ} = szeros(T, Nλ, 6)

λlength(joint::Joint{T,Nλ}) where {T,Nλ} = Nλ
blength(joint::Joint{T,Nλ,Nb}) where {T,Nλ,Nb} = Nb
ηlength(joint::Joint{T,Nλ,Nb,N}) where {T,Nλ,Nb,N} = N

function get_sγ(joint::Joint{T,Nλ,Nb}, η) where {T,Nλ,Nb}
    s = η[SVector{Nb,Int}(1:Nb)]
    γ = η[SVector{Nb,Int}(Nb .+ (1:Nb))]
    return s, γ
end

function λindex(joint::Joint{T,Nλ,Nb,N}, s::Int) where {T,Nλ,Nb,N}
    ind = SVector{N,Int}(s+1:s+N)
    return ind
end

## Discrete-time position derivatives (for dynamics)
@inline function impulse_map_parent(joint::Joint, body1::Node, body2::Node, childid, λ, Δt)
    if body2.id == childid
        return impulse_map_parent(joint, current_configuration(body1.state)..., current_configuration(body2.state)..., λ)
    else
        return zero(joint)
    end
end

@inline function impulse_map_child(joint::Joint, body1::Node, body2::Node, childid, λ, Δt)
    if body2.id == childid
        return impulse_map_child(joint, current_configuration(body1.state)..., current_configuration(body2.state)..., λ)
    else
        return zero(joint)
    end
end

## Discrete-time velocity derivatives (for dynamics)
@inline function constraint_jacobian_parent(joint::Joint, body1::Node, body2::Node, childid, λ, Δt)
    if body2.id == childid
        return constraint_jacobian_parent(joint, next_configuration(body1.state, Δt)..., next_configuration(body2.state, Δt)..., λ)
    else
        return zero(joint)
    end
end
@inline function constraint_jacobian_child(joint::Joint, body1::Node, body2::Node, childid, λ, Δt)
    if body2.id == childid
        return constraint_jacobian_child(joint, next_configuration(body1.state, Δt)..., next_configuration(body2.state, Δt)..., λ)

    else
        return zero(joint)
    end
end


### Springs and Dampers (for dynamics)
@inline function springforcea(joint::Joint, body1::Node, body2::Node, Δt, childid; unitary::Bool=false)
    if body2.id == childid
        return springforcea(joint, body1, body2, Δt, unitary=unitary)
    else
        return szeros(T, 6)
    end
end
@inline function springforceb(joint::Joint, body1::Node, body2::Node, Δt, childid; unitary::Bool=false)
    if body2.id == childid
        return springforceb(joint, body1, body2, Δt, unitary=unitary)
    else
        return szeros(T, 6)
    end
end

@inline function damperforcea(joint::Joint, body1::Node, body2::Node, Δt, childid; unitary::Bool=false)
    if body2.id == childid
        return damperforcea(joint, body1, body2, Δt, unitary=unitary)
    else
        return szeros(T, 6)
    end
end
@inline function damperforceb(joint::Joint, body1::Node, body2::Node, Δt, childid; unitary::Bool=false)
    if body2.id == childid
        return damperforceb(joint, body1, body2, Δt, unitary=unitary)
    else
        return szeros(T, 6)
    end
end

# ### Forcing (for dynamics)
@inline function apply_input!(joint::Joint, body1::Node, body2::Node, Δt::T, clear::Bool) where T
    apply_input!(joint, body1.state, body2.state, Δt, clear)
    return
end

Joint0 = Joint{T,0} where T
Joint1 = Joint{T,1} where T
Joint2 = Joint{T,2} where T
Joint3 = Joint{T,3} where T

# Base.show(io::IO, joint::Joint) = summary(io, joint)

### Constaint and nullspace matrices
@inline constraintmat(::Joint0{T}) where T = szeros(T,0,3)
@inline nullspacemat(::Joint0{T}) where T = SMatrix{3,3,T,9}(I)
@inline constraintmat(joint::Joint1) = joint.V3
@inline nullspacemat(joint::Joint1) = joint.V12
@inline constraintmat(joint::Joint2) = joint.V12
@inline nullspacemat(joint::Joint2) = joint.V3
@inline constraintmat(::Joint3{T}) where T = SMatrix{3,3,T,9}(I)
@inline nullspacemat(::Joint3{T}) where T = szeros(T,0,3)

### Constraints and derivatives
## Position level constraint wrappers
@inline constraint(joint::Joint, body1::Node, body2::Node, λ, Δt) = constraint(joint, next_configuration(body1.state, Δt)..., next_configuration(body2.state, Δt)..., λ)

@inline function constraint_jacobian_configuration(joint::Joint{T,Nλ}, λ) where {T,Nλ}
    return Diagonal(+1.00e-10 * sones(T,Nλ))
end

## Discrete-time position derivatives (for dynamics)
# Wrappers 1
@inline constraint_jacobian_parent(joint::Joint, body1::Node, body2::Node, λ, Δt) = constraint_jacobian_parent(joint, next_configuration(body1.state, Δt)..., next_configuration(body2.state, Δt)..., λ)
@inline constraint_jacobian_child(joint::Joint, body1::Node, body2::Node, λ, Δt) = constraint_jacobian_child(joint, next_configuration(body1.state, Δt)..., next_configuration(body2.state, Δt)..., λ)

### Force derivatives (for linearization)
## Forcing
@inline function set_input!(joint::Joint, Fτ::SVector)
    joint.Fτ = zerodimstaticadjoint(nullspacemat(joint)) * Fτ
    return
end
@inline set_input!(joint::Joint) = return

@inline function add_force!(joint::Joint, Fτ::SVector)
    joint.Fτ += zerodimstaticadjoint(nullspacemat(joint)) * Fτ
    return
end
@inline add_force!(joint::Joint) = return

## Derivative wrappers
@inline function ∂Fτ∂ua(joint::Joint, body1::Node, body2::Node, Δt, childid)
    return ∂Fτ∂ua(joint, body1.state, body2.state, Δt) * zerodimstaticadjoint(nullspacemat(joint))
end

@inline function ∂Fτ∂ub(joint::Joint{T,Nλ}, body1::Node, body2::Node, Δt, childid) where {T,Nλ}
    if body2.id == childid
        return ∂Fτ∂ub(joint, body1.state, body2.state, Δt) * zerodimstaticadjoint(nullspacemat(joint))
    else
        return szeros(T, 6, 3 - Nλ)
    end
end

## Minimal coordinates
@inline minimal_coordinates(joint::Joint{T,Nλ}) where {T,Nλ} = szeros(T, 3 - Nλ)

## Limits
function add_limits(mech::Mechanism, eq::JointConstraint;
    # NOTE: this only works for joints between serial chains (ie, single child joints)
    tra_limits=eq.constraints[1].joint_limits,
    rot_limits=eq.constraints[1].joint_limits)

    # update translational
    tra = eq.constraints[1]
    T = typeof(tra).parameters[1]
    Nλ = typeof(tra).parameters[2]
    Nb½ = length(tra_limits[1])
    Nb = 2Nb½
    N̄λ = 3 - Nλ
    N = Nλ + 2Nb
    tra_limit = (Translational{T,Nλ,Nb,N,Nb½,N̄λ}(tra.V3, tra.V12, tra.vertices, tra.spring, tra.damper, tra.spring_offset, tra_limits, tra.spring_type, tra.Fτ), eq.parentid, eq.childids[1])

    # update rotational
    rot = eq.constraints[2]
    T = typeof(rot).parameters[1]
    Nλ = typeof(rot).parameters[2]
    Nb½ = length(rot_limits[1])
    Nb = 2Nb½
    N̄λ = 3 - Nλ
    N = Nλ + 2Nb
    rot_limit = (Rotational{T,Nλ,Nb,N,Nb½,N̄λ}(rot.V3, rot.V12, rot.qoffset, rot.spring, rot.damper, rot.spring_offset, rot_limits, rot.spring_type, rot.Fτ), eq.parentid, eq.childids[1])
    JointConstraint((tra_limit, rot_limit); name=eq.name)
end
