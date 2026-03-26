using HeterogeneousArrays
using ComponentArrays
using Test
using Unitful
using RecursiveArrayTools
using LinearAlgebra
import DifferentialEquations as DE

@testset "DE Integration: Heterogeneous vs ComponentArrays" begin
    # 1. Setup Parameters and Time
    p = (σ = 10.0, ρ = 28.0, β = 8/3)
    tspan = (0.0, 0.01)

    # Define the physics/system once to be reused
    function lorenz!(du, u, p, t)
        # Both packages support getproperty/dot access
        x, y = u.coord
        z = u.z

        du.coord[1] = p.σ * (y - x)
        du.coord[2] = x * (p.ρ - z) - y
        du.z = x * y - p.β * z
        return nothing
    end

    # 2. Initialize both types
    u0_het = HeterogeneousVector(coord = [1.0, 0.0], z = 0.0)
    u0_comp = ComponentVector(coord = [1.0, 0.0], z = 0.0)

    # 3. Warm up (to JIT compile the ODE solver for both types)
    prob_het = DE.ODEProblem(lorenz!, u0_het, tspan, p)
    prob_comp = DE.ODEProblem(lorenz!, u0_comp, tspan, p)

    sol_het = DE.solve(prob_het, DE.Tsit5())
    sol_comp = DE.solve(prob_comp, DE.Tsit5())

    # 4. Measure Allocations & Correctness
    # We use @allocated on a fresh solve to ensure zero/minimal overhead
    allocs_het = @allocated DE.solve(prob_het, DE.Tsit5(), reltol = 1e-6)
    allocs_comp = @allocated DE.solve(prob_comp, DE.Tsit5(), reltol = 1e-6)

    # --- TESTS ---

    # A. Verify Result Parity
    # Check that the final state is numerically identical
    @test sol_het.u[end].coord ≈ sol_comp.u[end].coord
    @test sol_het.u[end].z ≈ sol_comp.u[end].z

    # B. Verify Performance Parity
    # HeterogeneousArrays should not be significantly "heavier" than ComponentArrays
    # for homogeneous Float64 data.
    @testset "Allocation Comparison" begin
        # This is very worying if HeterogeneousArrays allocates more than 2.5x the allocations of ComponentArrays
        # Double check with Jakob 
        # we expect roughly double the amount of allocations. 
        @test allocs_het <= allocs_comp * 2.5
        @info "Allocations - Heterogeneous: $allocs_het, Component: $allocs_comp"
    end

    # C. Verify Type Integrity
    @test sol_het.u[end] isa HeterogeneousVector
    @test sol_comp.u[end] isa ComponentVector
end

@testset "ODE Integration Consistency - Full 6-Vector Comparison" begin
    # 1. Setup Physical Constants
    r0_raw, v0_raw = [1131.34, -2282.34, 6672.42], [-5.64, 4.30, 2.42]
    μ_raw, Δt_raw = 398600.44, 3600.0
    r0_u, v0_u = r0_raw * u"km", v0_raw * u"km/s"
    μ_u, Δt_u = μ_raw * u"km^3/s^2", Δt_raw * u"s"

    # Kernels
    f_part(dy, y, μ, t) = (
        r_mag = norm(y.x[1]); dy.x[1] .= y.x[2]; dy.x[2] .= -μ .* y.x[1] ./ r_mag^3)
    f_named(dy, y, μ, t) = (r_mag = norm(y.r); dy.r .= y.v; dy.v .= -μ .* y.r ./ r_mag^3)

    common_args = (alg = DE.Vern8(), dt = 1e-3)#, adaptive=true)

    # 2. Define all 6 Problem Variations
    probs = [
        ("1. HeterogeneousVector (No Units)",
            DE.ODEProblem(
                f_named, HeterogeneousVector(r = r0_raw, v = v0_raw), (
                    0.0, Δt_raw), μ_raw)),
        ("2. HeterogeneousVector (Units)",
            DE.ODEProblem(
                f_named, HeterogeneousVector(r = r0_u, v = v0_u), (
                    0.0u"s", Δt_u), μ_u)),
        ("3. ArrayPartition (No Units)",
            DE.ODEProblem(f_part, ArrayPartition(r0_raw, v0_raw), (0.0, Δt_raw), μ_raw)),
        ("4. ArrayPartition (Units)",
            DE.ODEProblem(f_part, ArrayPartition(r0_u, v0_u), (0.0u"s", Δt_u), μ_u)),
        ("5. ComponentVector (No Units)",
            DE.ODEProblem(f_named, ComponentVector(r = r0_raw, v = v0_raw), (0.0, Δt_raw), μ_raw)),
        ("6. ComponentVector (Units)",
            DE.ODEProblem(f_named, ComponentVector(r = r0_u, v = v0_u), (0.0u"s", Δt_u), μ_u))
    ]

    # 3. Benchmarking Loop
    println("\n" * "─" ^ 65)
    println(rpad("Implementation Strategy", 35), lpad("Time (ms)", 15))
    println("─" ^ 65)

    results = Dict()
    for (label, prob) in probs
        # Warmup to JIT compile
        DE.solve(prob; common_args...)
        # Benchmark (Minimum time)
        t = @belapsed DE.solve($prob; $common_args...)
        results[label] = t
        println(rpad(label, 35), lpad(round(t * 1000, digits = 4), 15))
    end
    println("─" ^ 65)

    # 4. Numerical Validation
    @testset "Verification vs Baseline" begin
        # Extract baseline from the ArrayPartition (now at index 3)
        # Or more robustly: find the first ArrayPartition in the list
        sol_ref = DE.solve(probs[3][2]; common_args...)
        u_ref = sol_ref.u[end]

        # ArrayPartition uses .x[i]
        final_std = vcat(ustrip.(u_ref.x[1]), ustrip.(u_ref.x[2]))

        for (label, prob) in probs
            sol = DE.solve(prob; common_args...)
            u = sol.u[end]

            # Handle different indexing styles for extraction
            val = if hasproperty(u, :r)
                # HeterogeneousVector and ComponentVector use .r and .v
                vcat(ustrip.(u.r), ustrip.(u.v))
            else
                # ArrayPartition uses .x[1] and .x[2]
                vcat(ustrip.(u.x[1]), ustrip.(u.x[2]))
            end

            @test val ≈ final_std rtol=1e-13
        end
    end
end

@testset "Simple Pendulum Test" begin
    # --- 1. Parameters & Initial Conditions ---
    # L: length of pendulum, g: gravity
    L = 1.0u"m"
    g = 9.81u"m/s^2"

    # Initial state: θ = 45 degrees, ω = 0 rad/s
    # Note: we use 0.0u"s^-1" to ensure the type is a Quantity
    u0 = HeterogeneousVector(θ = 0.785, ω = 0.0u"s^-1")
    tspan = (0.0u"s", 5.0u"s")

    # --- 2. ODE Function ---
    function pendulum_f!(du, u, p, t)
        L, g = p
        # θ_dot = ω
        du.θ = u.ω
        # ω_dot = - (g/L) * sin(θ)
        du.ω = -(g / L) * sin(u.θ)
    end

    # # --- 3. Solver Setup ---
    # # We use a custom norm to handle the mix of Float64 (angle) and Quantity (ω)
    # const PENDULUM_NORM = (u, t) -> maximum(abs.(ustrip.(u)))

    abstol_struct = 1e-2 .* oneunit.(u0)
    prob = DE.ODEProblem(pendulum_f!, u0, tspan, (L, g))

    # Solve with high precision
    # sol = solve(prob, Vern8(), reltol=1e-12, abstol=1e-12, internalnorm=PENDULUM_NORM)
    # sol = DE.solve(prob, DE.Vern8();abstol=1e-12)
    sol = DE.solve(prob, DE.Vern8(); abstol = abstol_struct)

    # --- 4. Verification ---

    @testset "Physical Consistency" begin
        # 1. Check types
        @test sol.u[end] isa HeterogeneousVector
        @test sol.u[end].ω isa Unitful.Quantity

        # 2. Conservation of Energy check
        # E = (1/2) * L^2 * ω^2 + g * L * (1 - cos(θ))
        # keep units in this calculation to ensure correctness
        function energy(u)
            kin = 0.5 * ustrip(L)^2 * ustrip(u.ω)^2
            pot = ustrip(g) * ustrip(L) * (1 - cos(u.θ))
            return kin + pot
        end

        E0 = energy(sol.u[1])
        Ef = energy(sol.u[end])

        # Energy should be conserved in a simple pendulum
        @test E0 ≈ Ef rtol=1e-3
    end

    @testset "Named Field Access" begin
        # Verify we can access fields after integration
        @test sol.u[end].θ isa Float64
        @test unit(sol.u[end].ω) == u"s^-1"
    end
end
