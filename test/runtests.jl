using HeterogeneousArrays
using Test
using Unitful

@testset "Heterogeneous.jl" begin
    @testset "Basic Math and Units" begin
        x_1 = HeterogeneousVector(u = 3.1u"m", v = 5.2u"s")
        x_2 = HeterogeneousVector(u = 1.8u"m", v = 8.44u"s")
        a = 4.5
        b = 9.1

        # Test Out-of-place Broadcasting (copy)
        y_2 = a .* x_1 .+ b .* x_2

        # Manually calculate expected values
        expected_u = a * 3.1u"m" + b * 1.8u"m" # 30.33m
        expected_v = a * 5.2u"s" + b * 8.44u"s" # 100.204s

        @test y_2.u ≈ expected_u
        @test y_2.v ≈ expected_v

        # Test In-place Broadcasting (copyto!)
        y_1 = zero(x_1)
        y_1 .= a .* x_1 .+ b .* x_2

        @test y_1.u ≈ expected_u
        @test y_1.v ≈ expected_v
    end
end
