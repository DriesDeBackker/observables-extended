# Observables Extended

Observables in the spirit of Reactive Extensions (http://reactivex.io/) for Elixir, based on the Observables library by C. De Troyer (https://github.com/m1dnight/observables).

Extended with advanced primitives for combination and reactive programming with multivariate lifted functions.

Mainly for academic purposes, namely to explore propagation semantics of (a)synchronous data streams, in particular various combinations of such streams.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `observables_extended` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:observables_extended, "~> 0.3.2"}
  ]
end
```