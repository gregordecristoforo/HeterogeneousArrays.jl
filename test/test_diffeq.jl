using HeterogeneousArrays
using Test
import DifferentialEquations as DE

@testset "DifferentialEquations Integration (Unitless)" begin
    # Lorentz System Parameters
    p = (σ = 10.0, ρ = 28.0, β = 8/3)
    tspan = (0.0, 0.1) # Short run for testing

    # Initial state as a HeterogeneousVector
    # We split the state into 'coord' (vector) and 'z' (scalar) to test mixed segments
    u0 = HeterogeneousVector(coord = [1.0, 0.0], z = 0.0)

    function lorenz!(du, u, p, t)
        x, y = u.coord
        z = u.z

        # Access via named properties (testing getproperty)
        du.coord[1] = p.σ * (y - x)
        du.coord[2] = x * (p.ρ - z) - y
        du.z = x * y - p.β * z
        return nothing
    end

    # Define and Solve
    # This exercises similar(u0), copyto!(dest, bc), and indexing
    prob = DE.ODEProblem(lorenz!, u0, tspan, p)

    # Using Tsit5 as it's the standard reliable workhorse
    sol = DE.solve(prob, DE.Tsit5(), reltol = 1e-6, abstol = 1e-6)

    # 1. Check successful integration
    @test sol.retcode == DE.ReturnCode.Success

    # 2. Verify output type preservation
    @test sol.u[end] isa HeterogeneousVector
    @test propertynames(sol.u[end]) == (:coord, :z)

    # 3. Verify the state actually changed
    @test sol.u[end].coord != [1.0, 0.0]
    @test sol.u[end].z != 0.0
end
