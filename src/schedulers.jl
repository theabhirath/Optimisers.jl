using Base.Iterators: Cycle, Zip, Stateful,
                      Repeated, Take, TakeWhile

# f(t, p) = (2 / π) * abs(asin(sin(π * (t - 1) / p)))
# sine(t, p = 1.) = (2 / π) * abs(asin(sin(π * (t - 1) / p)))

# Simple scheduling can happen as a basic closure.
triangle(t) = (1 - 2 * abs(round(Int, t/2) - t/2))

const BaseIterators = Union{Cycle, Zip,
                            Stateful, Repeated,
                            Take, TakeWhile}

mutable struct Schedule{O,F}
  f::F
  opt::O
  cursor::Float32
end

"""
    Schedule(f, opt)

Create a scheduled optimiser whose update rule is controlled by `f`.

`f` can be any callable, while `opt` can be any optimiser.

See also [next](@ref), [init](@ref)
"""
function Schedule(f, opt)
  Schedule(f, opt, 1.f0 + eps(Float32)) 
end

# Timestep: t - always depends on run
# Phase: p - mostly likely constant

# What we want to "schedule" - everything (so will have to let people mess with things)
# Most likely learning rate
# If `f` relies on only time - it can be generated on the fly

# st = (t, timestep)
function next(itr::T, st) where T <: BaseIterators
  t, ts = st
  @show st
  iterate(itr, ts)
end

function next(arr::T, st) where T
  t, ts = st
  iterate(arr, ts)
end

next(f, (t,ts)) = f(t .+ ts), (t .+ ts, ts)

next_opt(o::T, kwargs...) where T = T(o, kwargs...)

"""
    next(s::Schedule, state)

Returns a new optimiser as described by the scheduler function
and the optimiser. This allocates a new optimiser on the stack, keeping the original one intact.

The state is a tuple of the state as defined by the scheduling policy.
"""
function next(s::Schedule{O}, st) where O
  snew, schedst = next(s.f, st)
  @show schedst
  ADAM(s.opt, eta = snew * s.opt.eta), (snew, schedst) #replace with O(..)
end

init(f, x) = (1, 1)
init(itr::T, x) where T <: BaseIterators = iterate(itr)
init(s::Schedule, x) = (init(s.f, x), init(s.opt, x))

function apply(s::Schedule, x, dx, st)
  schedst, optst = st
  o, schedst2 = next(s, schedst)
  @show o
  Δ, optst2 = apply(o, x, dx, optst)
  Δ, (schedst2, optst2)
end

struct InvDecay{T}
  decay::T
end

# (start, step) -> consider step to be a function/ vector of step sizes?
(inv::InvDecay)(t) = 1 / (1 + inv.decay * t)

InvDecay(s = 0.1f0) = InvDecay{typeof(s)}(s)

sine(p) = t -> sin(Float32(π) * t / p)
