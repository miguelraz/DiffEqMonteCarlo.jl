function solve(prob::AbstractMonteCarloProblem,alg::Union{DEAlgorithm,Void}=nothing;num_monte=10000,parallel_type=:pmap,kwargs...)

  if parallel_type == :pmap
    elapsedTime = @elapsed solution_data = pmap((i)-> begin
      new_prob = prob.prob_func(deepcopy(prob.prob),i)
      prob.output_func(solve(new_prob,alg;kwargs...),i)
    end,1:num_monte)
    solution_data = convert(Array{typeof(solution_data[1])},solution_data)

  elseif parallel_type == :parfor
    elapsedTime = @elapsed solution_data = @sync @parallel (vcat) for i in 1:num_monte
      new_prob = prob.prob_func(deepcopy(prob.prob),i)
      prob.output_func(solve(new_prob,alg;kwargs...),i)
    end

  elseif parallel_type == :threads
    solution_data = Vector{Any}()
    for i in 1:Threads.nthreads()
      push!(solution_data,[])
    end
    elapsedTime = @elapsed Threads.@threads for i in 1:num_monte
      new_prob = prob.prob_func(deepcopy(prob.prob),i)
      push!(solution_data[Threads.threadid()],prob.output_func(solve(new_prob,alg;kwargs...),i))
    end
    solution_data = vcat(solution_data...)
    solution_data = convert(Array{typeof(solution_data[1])},solution_data)

  elseif parallel_type == :split_threads
    elapsedTime = @elapsed solution_data = @sync @parallel (vcat) for procid in 1:nprocs()
      _num_monte = num_monte÷nprocs() # probably can be made more even?
      if procid == nprocs()
        _num_monte = num_monte-_num_monte*(nprocs()-1)
      end
      thread_monte(prob,num_monte,alg,procid,kwargs...)
    end

  elseif parallel_type == :none
    solution_data = Vector{Any}()
    elapsedTime = @elapsed for i in 1:num_monte
      new_prob = prob.prob_func(deepcopy(prob.prob),i)
      push!(solution_data,prob.output_func(solve(new_prob,alg;kwargs...),i))
    end
    solution_data = convert(Array{typeof(solution_data[1])},solution_data)

  else
    error("Method $parallel_type is not a valid parallelism method.")
  end

  MonteCarloSolution(solution_data,elapsedTime)
end

function thread_monte(prob,num_monte,alg,procid,kwargs...)
  solution_data = Vector{Any}()
  for i in 1:Threads.nthreads()
    push!(solution_data,[])
  end
  elapsedTime = @elapsed Threads.@threads for i in ((procid-1)*num_monte+1):(procid*num_monte)
    new_prob = prob.prob_func(deepcopy(prob.prob),i)
    push!(solution_data[Threads.threadid()],prob.output_func(solve(new_prob,alg;kwargs...),i))
  end
  solution_data = vcat(solution_data...)
  solution_data = convert(Array{typeof(solution_data[1])},solution_data)
end
