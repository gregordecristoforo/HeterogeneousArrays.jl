@testset "Allocation Logic (similar)" begin
    x = HeterogeneousVector(pos = [1.0u"m"], id = [1])

    @testset "Helpers & Zero-Initialization" begin
        r_sim = HeterogeneousArrays._similar_field(Ref(10), Float64)
        @test r_sim isa Ref{Float64}
        @test r_sim[] == 0.0
    end

    @testset "Type Overrides" begin
        y_float = similar(x, Float64)
        @test y_float isa HeterogeneousVector
        @test eltype(y_float.id) == Float64
        @test !(y_float isa Array)
    end
end

@testset "Advanced Allocation Logic (Multi-Type similar)" begin
    x = HeterogeneousVector(pos = [1.0, 2.0]u"m", id = [10, 20])

    @testset "Variadic Type Overrides" begin
        y = @inferred similar(x, Float32, Int16)
        @test eltype(y.pos) === Float32
        @test eltype(y.id) === Int16
        @test y isa HeterogeneousVector
    end

    @testset "Unitful Type Overrides" begin
        L_dim = dimension(u"m")
        TargetUnitType = Quantity{Float64, L_dim, typeof(u"m")}
        y = @inferred similar(x, TargetUnitType, Float64)
        @test y isa HeterogeneousVector
        @test eltype(y.pos) === TargetUnitType
        @test eltype(y.id) === Float64
        @test unit(y.pos[1]) === u"m"
    end

    @testset "Uniform Override" begin
        y = @inferred similar(x, Float64)
        @test eltype(y.pos) === Float64
        @test eltype(y.id) === Float64
    end

    @testset "Error Handling" begin
        @test_throws DimensionMismatch similar(x, Float64, Int, Bool)
    end
end

@testset "Zero-Initialization" begin
    x = HeterogeneousVector(pos = [1.0, 2.0]u"m", id = [10, 20])
    z = @inferred zero(x)
    @test z isa HeterogeneousVector
    @test propertynames(z) == (:pos, :id)
    @test all(z.pos .== 0.0u"m")
    @test all(z.id .== 0)
    @test eltype(z.pos) === eltype(x.pos)
    @test eltype(z.id) === eltype(x.id)
    @test z.pos !== x.pos
    @test z.id !== x.id
end

@testset "Keyword-based similar" begin
    x = HeterogeneousVector(pos = [1.0, 2.0]u"m", id = [10, 20])
    y = similar(x, id = Float32)
    @test eltype(y.id) === Float32
    @test eltype(y.pos) === eltype(x.pos)
    z = similar(x, id = Float64, pos = Float64)
    @test eltype(z.id) === Float64
    @test eltype(z.pos) === Float64
end

@testset "Keyword-based similar errors" begin
    x = HeterogeneousVector(pos = [1.0, 2.0]u"m", id = [10, 20])
    @test_throws ArgumentError similar(x, non_existent_field = Float64)
    try
        similar(x, typo = Int)
    catch e
        @test contains(e.msg, "Field 'typo' does not exist")
        @test contains(e.msg, "pos")
        @test contains(e.msg, "id")
    end
    @test_nowarn similar(x, pos = Float32, id = Int32)
end
