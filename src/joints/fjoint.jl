# Standard translational or rotational joint
abstract type FJoint{T,N} <: AbstractJoint{T,N} end

FJoint0 = FJoint{T,0} where T
FJoint1 = FJoint{T,1} where T
FJoint2 = FJoint{T,2} where T
FJoint3 = FJoint{T,3} where T

Base.show(io::IO, joint::FJoint) = summary(io, joint)

### Constaint and nullspace matrices
@inline constraintmat(::FJoint0{T}) where T = szeros(T,0,3)
@inline nullspacemat(::FJoint0{T}) where T = SMatrix{3,3,T,9}(I)
@inline constraintmat(joint::FJoint1) = joint.V3
@inline nullspacemat(joint::FJoint1) = joint.V12
@inline constraintmat(joint::FJoint2) = joint.V12
@inline nullspacemat(joint::FJoint2) = joint.V3
@inline constraintmat(::FJoint3{T}) where T = SMatrix{3,3,T,9}(I)
@inline nullspacemat(::FJoint3{T}) where T = szeros(T,0,3)


### Constraints and derivatives
## Position level constraint wrappers
@inline g(joint::FJoint{T,N}, body1::Body, body2::Body, Δt, λ::AbstractVector) where{T,N} = constraintmat(joint) * g(joint, body1, body2, Δt) * Δt .- SVector{N}(λ)
@inline g(joint::FJoint{T,N}, body1::Origin, body2::Body, Δt, λ::AbstractVector) where{T,N} = constraintmat(joint) * g(joint, body1, body2, Δt) * Δt .- SVector{N}(λ)

@inline function ∂g∂posa(joint::FJoint, body1::Body, body2::Body, Δt)
    X, Q = ∂g∂posa(joint, posargsnext(body1.state, Δt)..., posargsnext(body2.state, Δt)...) # the Δt factor comes from g(joint::FJoint
    return Δt * X, Δt * Q
end
@inline function ∂g∂posb(joint::FJoint, body1::Body, body2::Body, Δt)
    X, Q = ∂g∂posb(joint, posargsnext(body1.state, Δt)..., posargsnext(body2.state, Δt)...) # the Δt factor comes from g(joint::FJoint
    return Δt * X, Δt * Q
end
@inline function ∂g∂posb(joint::FJoint, body1::Origin, body2::Body, Δt)
    X, Q = ∂g∂posb(joint, posargsnext(body2.state, Δt)...) # the Δt factor comes from g(joint::FJoint
    return Δt * X, Δt * Q
end

### Constraints and derivatives
## Discrete-time position wrappers (for dynamics)
@inline function ∂g∂ʳself(joint::FJoint{T,N}) where {T,N}
    return -1.0 * sones(T,N)
end

### Force derivatives (for linearization)
## Forcing
@inline function setForce!(joint::FJoint, Fτ::SVector)
    joint.Fτ = zerodimstaticadjoint(nullspacemat(joint)) * Fτ
    return
end
@inline setForce!(joint::FJoint) = return


@inline function addForce!(joint::FJoint, Fτ::SVector)
    joint.Fτ += zerodimstaticadjoint(nullspacemat(joint)) * Fτ
    return
end
@inline addForce!(joint::FJoint) = return

## Derivative wrappers
@inline function ∂Fτ∂ua(joint::FJoint{T,N}, body1::Body, body2::Body, childid) where {T,N}
    # return ∂Fτ∂ua(joint, body1.state, body2.state) * zerodimstaticadjoint(nullspacemat(joint))
    return ∂Fτ∂ua(joint, body1.state, body2.state) * zerodimstaticadjoint(szeros(T,0,3)) # TODO this is because there is no control on the nullspacedims of the FJoint
end
@inline function ∂Fτ∂ub(joint::FJoint{T,N}, body1::Body, body2::Body, childid) where {T,N}
    if body2.id == childid
        # return ∂Fτ∂ub(joint, body1.state, body2.state) * zerodimstaticadjoint(nullspacemat(joint))
        return ∂Fτ∂ub(joint, body1.state, body2.state) * zerodimstaticadjoint(szeros(T,0,3)) # TODO this is because there is no control on the nullspacedims of the FJoint
    else
        return ∂Fτ∂ub(joint)
    end
end
@inline function ∂Fτ∂ub(joint::FJoint{T,N}, body1::Origin, body2::Body, childid) where {T,N}
    if body2.id == childid
        # return return ∂Fτ∂ub(joint, body2.state) * zerodimstaticadjoint(nullspacemat(joint))
        return return ∂Fτ∂ub(joint, body2.state) * zerodimstaticadjoint(szeros(T,0,3)) # TODO this is because there is no control on the nullspacedims of the FJoint
    else
        return ∂Fτ∂ub(joint)
    end
end

# @inline ∂Fτ∂ub(joint::FJoint{T,N}) where {T,N} = szeros(T, 6, 3 - N) # TODO zero function?
@inline ∂Fτ∂ub(joint::FJoint{T,N}) where {T,N} = szeros(T, 6, 0) # TODO zero function? # TODO this is because there is no control on the nullspacedims of the FJoint


### Minimal coordinates
@inline minimalCoordinates(joint::FJoint{T,N}) where {T,N} = szeros(T, 3 - N)