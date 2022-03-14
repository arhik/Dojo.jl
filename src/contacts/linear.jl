"""
    LinearContact{T,N} <: Contact{T,N}

    contact object for impact and friction with a linearized friction cone

    friction_coefficient: value of friction coefficient
    surface_projector: mapping from world frame to surface tangent frame 
    surface_normal_projector: inverse/complement of surface_projector
    contact_point: position of contact on Body relative to center of mass 
    offset: position of contact relative to contact_point
"""
mutable struct LinearContact{T,N} <: Contact{T,N}
    friction_coefficient::T
    surface_projector::SMatrix{4,3,T,12}
    surface_normal_projector::Adjoint{T,SVector{3,T}} # inverse matrix
    contact_point::SVector{3,T}
    offset::SVector{3,T}

    function LinearContact(body::Body{T}, normal::AbstractVector, friction_coefficient; 
        contact_point=szeros(T, 3), 
        offset::AbstractVector=szeros(T, 3)) where T
        V1, V2, V3 = orthogonal_columns(normal)
        A = [V1 V2 V3]
        Ainv = inv(A)
        surface_normal_projector = Ainv[3, SA[1; 2; 3]]'
        surface_projector = SA{T}[
             1  0  0
            -1  0  0
             0  1  0
             0 -1  0
        ]
        new{Float64,12}(friction_coefficient, surface_projector, surface_normal_projector, contact_point, offset)
    end
end

function constraint(mechanism, contact::ContactConstraint{T,N,Nc,Cs}) where {T,N,Nc,Cs<:LinearContact{T,N}}
    model = contact.model
    body = get_body(mechanism, contact.parent_id)
    x2, v25, q2, ϕ25 = current_configuration_velocity(body.state)
    x3, q3 = next_configuration(body.state, mechanism.timestep)

    # transforms the velocities of the origin of the link into velocities along all 4 axes of the friction pyramid
    # vp = V(cp, B / W)_w velocity of the contact point cp, attached to body B wrt world frame, expressed in the world frame.
    vp = v25 + skew(vector_rotate(ϕ25, q3)) * (vector_rotate(model.contact_point, q3) - model.offset)
    γ = contact.impulses[2][1]
    sγ = contact.impulses_dual[2][1]
    ψ = contact.impulses[2][2]
    sψ = contact.impulses_dual[2][2]
    β = contact.impulses[2][@SVector [3,4,5,6]]
    sβ = contact.impulses_dual[2][@SVector [3,4,5,6]]
    SVector{6,T}(
        model.surface_normal_projector * (x3 + vector_rotate(model.contact_point,q3) - model.offset) - sγ,
        model.friction_coefficient * γ - sum(β) - sψ,
        (model.surface_projector * vp + ψ * sones(4) - sβ)...)
end

function constraint_jacobian_configuration(model::LinearContact, x3::AbstractVector, q3::Quaternion,
    x2::AbstractVector, v25::AbstractVector, q2::Quaternion, ϕ25::AbstractVector, 
    λ, timestep)
    V = [model.surface_normal_projector;
         szeros(1,3);
         szeros(4,3)]
    ∂v∂q3 = skew(vector_rotate(ϕ25, q3)) * ∂vector_rotate∂q(model.contact_point, q3)
    ∂v∂q3 += skew(model.offset - vector_rotate(model.contact_point, q3)) * ∂vector_rotate∂q(ϕ25, q3)
    Ω = [model.surface_normal_projector * ∂vector_rotate∂q(model.contact_point, q3);
        szeros(1,4);
        model.surface_projector * ∂v∂q3]
    return [V Ω]
end

function constraint_jacobian_velocity(model::LinearContact, x3::AbstractVector, q3::Quaternion,
    x2::AbstractVector, v25::AbstractVector, q2::Quaternion, ϕ25::AbstractVector, 
    λ, timestep)
    V = [model.surface_normal_projector * timestep;
         szeros(1,3);
         model.surface_projector]
    ∂v∂q3 = skew(vector_rotate(ϕ25, q3)) * ∂vector_rotate∂q(model.contact_point, q3)
    ∂v∂q3 += skew(model.offset - vector_rotate(model.contact_point, q3)) * ∂vector_rotate∂q(ϕ25, q3)
    ∂v∂ϕ25 = skew(model.offset - vector_rotate(model.contact_point, q3)) * ∂vector_rotate∂p(ϕ25, q3)
    Ω = [model.surface_normal_projector * ∂vector_rotate∂q(model.contact_point, q3) * rotational_integrator_jacobian_velocity(q2, ϕ25, timestep);
        szeros(1,3);
        model.surface_projector * (∂v∂ϕ25 + ∂v∂q3 * rotational_integrator_jacobian_velocity(q2, ϕ25, timestep))]
    return [V Ω]
end

function set_matrix_vector_entries!(mechanism::Mechanism, matrix_entry::Entry, vector_entry::Entry,
    contact::ContactConstraint{T,N,Nc,Cs,N½}) where {T,N,Nc,Cs<:LinearContact{T,N},N½}
    # ∇impulses[impulses .* impulses - μ; g - s] = [diag(impulses); -diag(0,1,1)]
    # ∇impulses[impulses .* impulses - μ; g - s] = [diag(impulses); -diag(1,0,0)]
    # (friction_coefficient γ - ψ) dependent of ψ = impulses[2][1:1]
    # B(z) * zdot - sβ dependent of sβ = impulses[2][2:end]
    friction_coefficient = contact.model.friction_coefficient
    γ = contact.impulses[2] + REG * neutral_vector(contact.model)
    s = contact.impulses_dual[2] + REG * neutral_vector(contact.model)

    ∇s1 = Diagonal(γ) # 6x6
    ∇s2 = Diagonal(-sones(T,6))
    ∇s = vcat(∇s1, ∇s2) # 12x6

    ∇γ1 = Diagonal(s) # 6x6
    ∇γ2 = @SMatrix[ 0  0  0  0  0  0;
                   friction_coefficient  0 -1 -1 -1 -1;
                    0  1  0  0  0  0;
                    0  1  0  0  0  0;
                    0  1  0  0  0  0;
                    0  1  0  0  0  0;]
    ∇γ = vcat(∇γ1, ∇γ2) # 12x6
    matrix_entry.value = hcat(∇s, ∇γ)

    # [-impulses .* impulses + μ; -g + s]
    vector_entry.value = vcat(-complementarityμ(mechanism, contact), -constraint(mechanism, contact))
    return
end
