if VERSION >= v"0.7.0-beta.0"
    using Test
else
    using Base.Test 
end

n = 10; # dimension

S = [(i+j)/100. for i = 1:n, j = 1:n]
b = ones(n);

A = 10 * I + 0.01*S*S'; # symmetric and positive defined matrix
function fun!(x,fx)
    fx[:] = A*x
end

function pc_exact!(x,fx)
    fx[:] = A\x
end

function pc_jacobi!(x,fx)
    fx[:] = Diagonal(diag(A))\x
end


tol = 1e-4
kwargs = [(:tol, tol)]

xAy, yATx = divand.checksym(n,fun!)
@test xAy ≈ yATx

x,success,niter0 = divand.conjugategradient(fun!,zeros(size(b)); kwargs...)
@test x ≈ zeros(size(b))

x,success,niter1 = divand.conjugategradient(fun!,b; kwargs...)
@test norm(A*x - b)/norm(b) < tol

x,success,niter2 = divand.conjugategradient(fun!,b; kwargs..., pc! = pc_exact!)
@test norm(A*x - b)/norm(b) < tol
@test niter2 == 1

x,success,niter3 = divand.conjugategradient(fun!,b; kwargs..., pc! = pc_jacobi!)
@test norm(A*x - b)/norm(b) < tol
@test niter3 <= niter1


# check type-stability
@inferred divand.conjugategradient(fun!,zeros(size(b)); kwargs..., pc! = pc_jacobi!)

