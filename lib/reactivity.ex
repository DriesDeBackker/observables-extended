defmodule Observables.Reactivity do

	alias Observables.Obs
	
	def lift2update(obs1, obs2, fun) do
		Obs.combinelatest2(obs1, obs2)
		|> Obs.map(fn {v1, v2} ->
			fun.(v1, v2) end)
	end

	def lift2stream(obs1, obs2, fun) do
		Obs.zip(obs1, obs2)
		|> Obs.map(fn {v1, v2} ->
			fun.(v1, v2) end)
	end

end