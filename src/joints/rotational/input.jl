################################################################################
# Control Input
################################################################################

function input_impulse!(joint::Rotational{T}, pbody::Node, cbody::Node,
    timestep::T, clear::Bool) where T

    axis_offset = joint.axis_offset
    τ = joint.input
    xa, qa = current_configuration(pbody.state)
    xb, qb = current_configuration(cbody.state)

    pbody.state.τ2 += vector_rotate(-τ, axis_offset)
    cbody.state.τ2 += vector_rotate(τ, inv(qb) * qa * axis_offset)
    clear && (joint.input = szeros(T,3))
    return
end

################################################################################
# Control Jacobian
################################################################################

function input_jacobian_control(relative::Symbol,
    joint::Rotational{T},
    xa::AbstractVector, qa::Quaternion,
    xb::AbstractVector, qb::Quaternion) where T

    axis_offset = joint.axis_offset
    if relative == :parent
        BFa = szeros(T, 3, 3)
        Bτa = - rotation_matrix(axis_offset)
        return [BFa; Bτa]
    elseif relative == :child
        BFb = szeros(T, 3, 3)
        Bτb = rotation_matrix(inv(qb) * qa * axis_offset)
        return [BFb; Bτb]
    end
end

function input_jacobian_configuration(relative::Symbol,
    joint::Rotational{T},
    xa::AbstractVector, qa::Quaternion,
    xb::AbstractVector, qb::Quaternion) where T

    axis_offset = joint.axis_offset
    τ = joint.input

    if relative == :parent
        FaXa = szeros(T,3,3)
        FaQa = szeros(T,3,4)
        τaXa = szeros(T,3,3)
        τaQa = szeros(T,3,4)
        FbXa = szeros(T,3,3)
        FbQa = szeros(T,3,4)
        τbXa = szeros(T,3,3)
        τbQa = rotation_matrix(inv(qb)) * ∂rotation_matrix∂q(qa * axis_offset, τ)#*LVᵀmat(qa)
        return FaXa, FaQa, τaXa, τaQa, FbXa, FbQa, τbXa, τbQa
    elseif relative == :child
        FaXb = szeros(T,3,3)
        FaQb = szeros(T,3,4)
        τaXb = szeros(T,3,3)
        τaQb = szeros(T,3,4)
        FbXb = szeros(T,3,3)
        FbQb = szeros(T,3,4)
        τbXb = szeros(T,3,3)
        τbQb = ∂rotation_matrix_inv∂q(qb, vector_rotate(τ, qa * axis_offset))#*LVᵀmat(qb)
        return FaXb, FaQb, τaXb, τaQb, FbXb, FbQb, τbXb, τbQb
    end
end
