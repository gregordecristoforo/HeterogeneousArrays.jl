@testset "Array Interface & Metadata" begin
    x = HeterogeneousVector(a = [1, 2, 3], b = 4.5)

    @testset "Indexing" begin
        @test x[1] == 1
        @test x[4] == 4.5
        @test_throws BoundsError x[5]
    end

    @testset "Iteration" begin
        v = HeterogeneousVector(d = [3.1u"m", 4.2u"m"], t = 5.0u"s")
        collected = collect(v)
        @test length(collected) == 3
        @test collected[1] == 3.1u"m"
        @test collected[3] == 5.0u"s"
    end

    @testset "Metadata" begin
        @test summary(x) == "$(typeof(x)) with members:"
        @test propertynames(x) == (:a, :b)
    end
end

@testset "State & Mutability" begin
    @testset "Direct Access" begin
        x = HeterogeneousVector(a = [1, 2, 3], b = 4.5)
        x.b = 7.8
        x.a[2] = 42
        @test x.b == 7.8
        @test x.a[2] == 42
        @test_throws ErrorException x.missing_field = 10
    end

    @testset "Copying & Identity" begin
        x = HeterogeneousVector(a = [1, 2, 3], b = 4.5)
        y = copy(x)
        @test y == x
        @test y !== x
        @test y.a !== x.a # Ensure deep copy of segments

        z = zero(x)
        copyto!(z, x)
        @test z == x
    end
end

@testset "Reference vs Copy Behavior" begin
    original_array = [1.0, 2.0, 3.0]
    original_scalar = 42.0

    v = HeterogeneousVector(vec = original_array, scalar = original_scalar)

    @testset "Array Referencing" begin
        original_array[1] = 99.0
        @test v.vec[1] == 99.0
        v.vec[2] = -7.0
        @test original_array[2] == -7.0
        @test pointer(v.vec) == pointer(original_array)
    end

    @testset "Scalar Wrapping" begin
        @test v.scalar == 42.0
        v.scalar = 100.0
        @test original_scalar == 42.0
    end
end
