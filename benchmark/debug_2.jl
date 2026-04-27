using FlexUnits, .UnitRegistry
# using OrdinaryDiffEq
using DifferentialEquations
using StaticArrays
using Plots
using BenchmarkTools
using LinearAlgebra
using ComponentArrays

function acceleration(u::AbstractVector{<:Quantity}, p::AbstractVector{<:Quantity}, t)
    fd = -sign(u.v)*0.5*p.ρ*u.v^2*p.Cd*p.A
    dv = fd/p.m - p.g
    dh = u.v
    return ComponentVector(v=dv, h=dh)
end

u0 = ComponentVector(v=0.0u"m/s", h=100u"m")
p  = ComponentVector(Cd=1.0u"", A=0.1u"m^2", ρ=1.0u"kg/m^3", m=50u"kg", g=9.81u"m/s^2")

tspan = (0.0u"s", 10.0u"s")
prob = ODEProblem{false, DifferentialEquations.SciMLBase.NoSpecialize}(acceleration, u0, tspan, p, abstol=[1e-6, 1e-6], reltol=[1e-6, 1e-6])
sol = solve(prob, Tsit5())
plt = plot(ustrip.(sol.t), [ustrip(u.v) for u in sol.u], label="Tsit5")
