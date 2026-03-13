function compute_nested!(d, o1, o2)
    @. d = o1 + o2 * 2.0
    return nothing
end

@testset "Nested HeterogeneousVectors" begin
    inner = HeterogeneousVector(x = [1.0, 2.0], y = 3.0)
    outer = HeterogeneousVector(sub = inner, bulk = [10.0, 20.0])

    @testset "Nested Access" begin
        @test outer.sub.x[1] == 1.0
        @test outer.sub.y == 3.0
    end

    @testset "Nested Broadcasting" begin
        res = outer .+ 1.0
        @test res isa HeterogeneousVector
        @test res.sub isa HeterogeneousVector
        @test res.sub.x == [2.0, 3.0]
        @test res.sub.y == 4.0
        @test res.bulk == [11.0, 21.0]
    end
end

@testset "Nested HeterogeneousVectors Operation" begin
    inner1 = HeterogeneousVector(a = [1.0, 2.0], b = 3.0)
    inner2 = HeterogeneousVector(a = [4.0, 5.0], b = 6.0)
    outer1 = HeterogeneousVector(sub = inner1, val = 10.0)
    outer2 = HeterogeneousVector(sub = inner2, val = 20.0)
    dest = zero(outer1)

    compute_nested!(dest, outer1, outer2)
    @test dest.sub.a == [9.0, 12.0]
    @test dest.sub.b == 15.0
    @test dest.val == 50.0
end

@testset "Deep Nesting" begin
    depth = 10
    v = HeterogeneousVector(x = 1.0)
    for i in 1:depth
        v = HeterogeneousVector(inner = v, val = Float64(i))
    end

    res = v .+ 1.0
    @test res isa HeterogeneousVector
    @test length(res) == length(v)

    function verify_nesting(current_v, current_depth)
        if current_depth == 0
            @test current_v.x == 1.0 + 1.0
            return
        end
        @test current_v.val == Float64(current_depth) + 1.0
        verify_nesting(current_v.inner, current_depth - 1)
    end

    verify_nesting(res, depth)
end
