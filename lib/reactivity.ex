defmodule Observables.Reactivity do

	alias Observables.Obs

	@doc """
	* Lifts a unary function and applies it to an observable.
	(Essentially a wrapper for the map operator on observables.)
	"""
	def liftapp(obs, fun) do
		obs |> Obs.map(fun)
	end

	@doc """
	* Lifts a binary function and applies it to two observables
	* Does not consume processed values, but keeps them as state until a more recent value is received,
	at which point the value is updated and a new output value is produced. 
	This is similar to a behaviour with discrete updates in FRP.
	"""
	def liftapp2_update(obs1, obs2, fun) do
		Obs.combine_2(obs1, obs2)
			|> Obs.map(fn {v1, v2} -> 
				fun.(v1, v2) end)
	end

	@doc """
	* Lifts an n-ary function and applies it to a list of n observables.
	* Does not consume processed values, but keeps them as state until a more recent value is received,
	at which point the value is updated and a new output value is produced. 
	This is similar to a behaviour with discrete updates in FRP.
	"""
	def liftappn_update(obss, fun, inits \\ nil) do
		Obs.combine_n(obss, inits)
			|> Obs.map(fn arg_tuple ->
				apply(fun, Tuple.to_list(arg_tuple)) end)
	end

	@doc """
	* Lifts a binary function and applies it to two observables
	* Consumes processed values in a stream-wise fashion.
	This is similar to event-stream processing in FRP.
	"""
	def liftapp2_stream(obs1, obs2, fun) do
		Obs.zip(obs1, obs2)
			|> Obs.map(fn {v1, v2} ->
				fun.(v1, v2) end)
	end

	@doc """
	* Lifts an n-ary function and applies it to a list of n observables.
	* Consumes processed values in a stream-wise fashion.
	This is similar to event-stream processing in FRP.
	"""
	def liftappn_stream(obss, fun) do
		Obs.zip_n(obss)
			|> Obs.map(fn arg_tuple ->
				apply(fun, Tuple.to_list(arg_tuple)) end)
	end

	@doc """
	* Lifts a function that can operate on lists of variable sizes
	and applies it to a variable sized list of observables, which is initially the given list.
	* Takes a higher order observable ob that announces new observables to add to the list of incoming dependencies.
	Observables that have stopped will be removed and operation will continue with the remaining ones.
	* Does not consume processed values, but keeps them as state until a more recent value is received,
	at which point the value is updated and a new output value is produced. 
	This is similar to a behaviour with discrete updates in FRP.
	"""
	def liftappvar_update(obs, obss, fun, inits \\ nil) do
		Obs.combine_var(obs, obss, inits)
			|> Obs.map(fn arg_tuple ->
				fun.(Tuple.to_list(arg_tuple)) end)
	end

	@doc """
	* Lifts a function that can operate on lists of variable sizes
	and applies it to a variable sized list of observables, which is initially the given list.
	* Takes a higher order observable ob that announces new observables to add to the list of incoming dependencies.
	Observables that have stopped will be removed and operation will continue with the remaining ones.
	* Consumes processed values in a stream-wise fashion. 
	This is similar to event-stream processing in FRP.
	"""
	def liftappvar_stream(obs, obss, fun) do
		Obs.zip_var(obs, obss)
			|> Obs.map(fn arg_tuple ->
				fun.(Tuple.to_list(arg_tuple)) end)
	end

end