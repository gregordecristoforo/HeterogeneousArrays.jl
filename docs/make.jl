using Documenter
using HeterogeneousArrays

makedocs(
    sitename = "HeterogeneousArrays Documentation",  # Package name
    modules = [HeterogeneousArrays],                 # Package module
    format = Documenter.HTML(),           # Generate HTML documentation
    pages = [
        "Home" => "index.md",             # Main page
        "API Reference" => "api.md"      # API documentation
    ],
    checkdocs = :exports                  # Only check exported symbols
)

# Deploy documentation to GitHub Pages (only in CI/CD)
if get(ENV, "CI", nothing) == "true"
    github_url = get(ENV, "GITHUB_SERVER_URL", "https://github.com")
    github_repo = get(ENV, "GITHUB_REPOSITORY", "")
    deploydocs(
        repo = "$github_url/$github_repo.git",
        devbranch = "main",
        push_preview = false
    )
end
