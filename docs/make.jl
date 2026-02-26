using Documenter

# Add the parent project to the load path
push!(LOAD_PATH, joinpath(@__DIR__, ".."))

using HeterogeneousArrays

makedocs(
    sitename = "HeterogeneousArrays Documentation",  # Package name
    modules = [HeterogeneousArrays],                 # Package module
    format = Documenter.HTML(),           # Generate HTML documentation
    pages = [
        "Home" => "index.md",             # Main page
        "API Reference" => "api.md",      # API documentation
    ],
    checkdocs = :exports                  # Only check exported symbols
)