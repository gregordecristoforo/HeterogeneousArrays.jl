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

    @testset "Indexing and Iteration" begin
        x = HeterogeneousVector(a = [1, 2, 3], b = 4.5)

        # Test indexing
        @test x[1] == 1
        @test x[2] == 2
        @test x[3] == 3
        @test x[4] == 4.5
        # Test out-of-bounds indexing
        @test_throws BoundsError x[5]

        # Test iteration
        collected = collect(x)
        @test collected == [1, 2, 3, 4.5]
    end
    @testset "Mutability and Property Access" begin
        x = HeterogeneousVector(a = [1, 2, 3], b = 4.5)
        # Test mutability of scalar field
        x.b = 7.8
        @test x.b == 7.8
        # Test mutability of array field
        x.a[2] = 42
        @test x.a == [1, 42, 3]
    end
    @testset "Broadcasting with Scalars and Arrays" begin
        x = HeterogeneousVector(a = [1, 2, 3], b = 4.5)
        scalar = 2.0
        # Test broadcasting with scalar
        y = scalar .* x
        @test y.a == [2.0, 4.0, 6.0]
        @test y.b == 9.0
    end
    @testset "Copy and Copyto!" begin
        x = HeterogeneousVector(a = [1, 2, 3], b = 4.5)
        y = copy(x)
        # Test copy
        @test y.a == x.a
        @test y.b == x.b
        @test y !== x  # Ensure it's a deep copy
        # Test copyto!
        z = zero(x)
        copyto!(z, x)
        @test z.a == x.a
        @test z.b == x.b
    end
    @testset "Field Access and Property Names" begin
        x = HeterogeneousVector(position = [1, 2, 3], velocity = 4.5)

        # Test property names
        @test propertynames(x) == (:position, :velocity)

        # Test field access
        @test x.position == [1, 2, 3]
        @test x.velocity == 4.5
    end
    @testset "Error Handling" begin
        x = HeterogeneousVector(a = [1, 2, 3], b = 4.5)
        # Test invalid property access
        @test_throws ErrorException x.c
        # Test invalid property assignment
        @test_throws ErrorException x.c = 10
    end
    @testset "Mixed Units and Types" begin
        x = HeterogeneousVector(a = 3.1u"m", b = 5.2)
        y = HeterogeneousVector(a = 1.8u"s", b = 8.44)

        # Test broadcasting with mixed units
        z = x .* y
        # Expected results
        expected_a = 3.1u"m" * 1.8u"s"  # Resulting unit: m*s
        expected_b = 5.2 * 8.44          # No units, just a scalar multiplication
        # Test the results
        @test z.a == expected_a          # Should be 5.58 m*s
        @test z.b == expected_b          # Should be 43.888
    end
    @testset "Iteration with Units" begin
        # Create a HeterogeneousVector with mixed fields, including units
        x = HeterogeneousVector(distance = [3.1u"m", 4.2u"m"], time = 5.0u"s", speed = [
            1.5u"m/s", 2.0u"m/s"])
        # Collect all elements using iteration
        collected = collect(x)
        # Manually define the expected result
        expected = [3.1u"m", 4.2u"m", 5.0u"s", 1.5u"m/s", 2.0u"m/s"]
        # Test that iteration produces the correct result
        @test collected == expected
        # Test that iteration works with a for loop
        iterated = []
        for element in x
            push!(iterated, element)
        end
        @test iterated == expected
        # Test that iteration works with `first` and `iterate`
        first_element, state = iterate(x)
        @test first_element == 3.1u"m"  # First element should be the first in the first field
        @test state !== nothing         # Ensure the state is valid
        # Continue iterating manually
        second_element, state = iterate(x, state)
        @test second_element == 4.2u"m"
        third_element, state = iterate(x, state)
        @test third_element == 5.0u"s"
        fourth_element, state = iterate(x, state)
        @test fourth_element == 1.5u"m/s"
        fifth_element, state = iterate(x, state)
        @test fifth_element == 2.0u"m/s"
        # Ensure iteration ends
    end
end
