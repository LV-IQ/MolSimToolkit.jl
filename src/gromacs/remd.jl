export remd_data

"""
    GromacsRMEDlog

Structure to store the log from a REMD simulation performed with Gromacs. 
This structure contains three fields:

- `steps`: Vector of steps at which the exchange was performed.
- `exchange_matrix`: Matrix of exchanges performed. 
  Each row corresponds to a step and each column to a replica. 
- `probability_matrix`: Matrix of probabilities of finding each replica at level of 
  perturbation. Each column corresponds to a replica and each row to a level of
  perturbation.

"""
struct GromacsHRMEDlog
    steps::Vector{Int}
    exchange_matrix::Matrix{Int}
    probability_matrix::Matrix{Float64}
end
const hrmed_production_log = "$(@__DIR__)" * "/../../test/data/hrmed/production.log"

"""
    remd_data(log::String)

Function to read the log file from a (H)REMD simulation performed with Gromacs.

Returns a `GromacsHRMEDlog` structure, containing the steps at which the exchange
was tried, the exchange matrix and the probability matrix. The exchange matrix
contains the replica number at each level of perturbation for each step. The
probability matrix contains the probability of finding each replica at each level.

Tested with Gromacs version 2019.4 output log.

# Example

First obtaina the REMD data from the log file:

```julia-repl
julia> using MolSimToolkit

julia> data = remd_data(MolSimToolkit.hrmed_production_log)

```

Then plot the exchange matrix, which will provide a visual
inspection of the exchange process:

```julia-repl
julia> using Plots

julia> plt = plot(
           data.steps, data.exchange_matrix,
           label=nothing,
           xlabel="simulations step",
           ylabel="replica at position",
           linewidth=2,
           palette = cgrad(:rainbow, rev=true),
           margin=0.5Plots.Measures.cm,
           ylims=[0, 9], yticks=(0:1:9, 0:1:9),
       )
```

An alternative visualization of the exchange process is
given by the probability matrix:

```julia-repl
julia> scatter(
           data.probability_matrix,
           labels= Ref("Replica ") .* string.((0:9)'),
           framestyle=:box,
           linewidth=2,
           ylims=(0,0.12), xlims=(0.7, 10.3),
           xlabel="Level", xticks=(1:10, 0:9),
           ylabel="Probability",
           alpha=0.5,
           margin=0.5Plots.Measures.cm,
       )
```

"""
function remd_data(log::String)
    if !isfile(log)
        throw(ArgumentError("File $log does not exist."))
    end
    step = 0
    nreplicas = 0
    swaps = Int[]
    steps = Int[]
    exchanges = Vector{Int}[]
    open(log, "r") do io
        for line in eachline(io)
            length(line) < 7 && continue
            if occursin("Replica exchange at step", line)
                data = split(line)
                step = parse(Int, data[5])
            end
            if line[1:7] == "Repl ex"
                data = split(line[8:end])
                if length(exchanges) == 0
                    nreplicas = parse(Int, data[end]) + 1
                    push!(exchanges, [i for i in 0:nreplicas-1])
                    push!(steps, 0)
                    swaps = zeros(Int, nreplicas)
                end
                swaps .= last(exchanges)
                iswap = 1
                for i in eachindex(data)
                    if data[i] == "x"
                        swaps[iswap-1], swaps[iswap] = swaps[iswap], swaps[iswap-1]
                        iswap -= 1
                    end
                    iswap += 1
                end
                push!(steps, step)
                push!(exchanges, copy(swaps))
            end
        end
    end
    exchange_matrix = zeros(Int, length(exchanges), nreplicas)
    for iframe in eachindex(exchanges)
        exchange_matrix[iframe, :] .= exchanges[iframe]
    end
    probability_matrix = reduce(hcat, [[count(==(i), exchange_matrix[:, j]) for i in 0:9] for j in 1:10]) ./ length(steps)
    return GromacsHRMEDlog(steps, exchange_matrix, probability_matrix)
end