# Shared helper for performance tests
function compute_inplace!(d, src1, src2)
    d .= src1 .+ src2
    return nothing
end

@testset "Performance & Static Dispatch Validation" begin
    x = HeterogeneousVector(a = 1.0u"m", b = [2.0u"m", 3.0u"m"])
    y = HeterogeneousVector(a = 4.0u"m", b = [5.0u"m", 6.0u"m"])

    @testset "Type Stability & Inference (Concrete)" begin
        type_a = typeof(x.a)
        type_b = typeof(x.b)
        type_hv = typeof(x)
        get_a(v) = v.a
        get_b(v) = v.b

        @test (@inferred get_a(x)) isa type_a
        @test (@inferred get_b(x)) isa type_b
        add_vecs(v1, v2) = v1 .+ v2
        @test (@inferred add_vecs(x, y)) isa type_hv
        f_fused(v1, v2) = @. exp(v1 / 1.0u"m") + v2 / 1.0u"m"
        expected_result_type = typeof(f_fused(x, y))
        @test (@inferred f_fused(x, y)) isa expected_result_type
    end

    @testset "Concrete Type Structural Validation" begin
        x = HeterogeneousVector(a = 1.0u"m", b = [2.0u"m", 3.0u"m"])
        ConcreteVectorType = Vector{Unitful.Quantity{Float64, Unitful.𝐋, typeof(u"m")}}
        get_b(hv) = hv.b
        @test (@inferred get_b(x)) isa ConcreteVectorType
        get_a_raw(hv) = getfield(NamedTuple(hv), :a)
        ConcreteRefType = Base.RefValue{Unitful.Quantity{Float64, Unitful.𝐋, typeof(u"m")}}
        @test (@inferred get_a_raw(x)) isa ConcreteRefType
    end

    @testset "Zero-Allocation In-Place Updates" begin
        dest = zero(x)
        compute_inplace!(dest, x, y)
        b = @benchmarkable compute_inplace!($dest, $x, $y)
        res = run(b)
        @test res.allocs == 0
    end
end
