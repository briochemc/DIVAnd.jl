# Adapted from
# from http://julialang.org/blog/2016/02/iteration
# to deal with fill values
# 3x3x3...x3 window box filtering
# and central point weight equals sum of all other points if present
# to add: loop ntimes over the filter; need to check how to copy/update the arrays...


function DIVAnd_filter3(A::AbstractArray, fillvalue, ntimes = 1)
    nd = ndims(A)
    # central weight
    cw = 1.0

    if ntimes == 0
        return A
    end

    out = similar(A)
    B = if ntimes > 1
        copy(A)
    else
        A
    end

    RI = CartesianIndices(size(A))

    I1, Iend = first(RI), last(RI)
    stencil = one(CartesianIndex(I1))

    for nn = 1:ntimes
        for indI in RI
            w = 0.0
            s = zero(eltype(out))

            # Define out[indI] fillvalue
            out[indI] = fillvalue
            if !isequal(B[indI], fillvalue)
                # https://github.com/JuliaLang/julia/issues/15276#issuecomment-297596373
                # let block work-around
                RJ = let indI = indI, I1 = I1, Iend = Iend, stencil = stencil
                    CartesianIndices(ntuple(
                        i ->
                            max(
                                I1[i],
                                indI[i] - stencil[i],
                            ):min(Iend[i], indI[i] + stencil[i]),
                        nd,
                    ))
                end

                for indJ in RJ
                    if !isequal(B[indJ], fillvalue)
                        s += B[indJ]
                        if indI == indJ
                            w += cw
                        else
                            w += 1.0
                        end
                    end
                    # end if not fill value
                end
                if w > 0.0
                    out[indI] = s / w
                end
            end
        end

        if ntimes > 1
            B .= out
        end
    end


    return out
end
