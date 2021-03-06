defmodule Observables.Reactivity do

	alias Observables.Obs

	@doc """
	* Lifts a unary function and applies it to an observable (essentially a wrapper for the map observable)
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
		Obs.combinelatest(obs1, obs2)
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
		Obs.combinelatest_n(obss, inits)
		|> Obs.map(fn arg_tuple ->
			apply(fun, Tuple.to_list(arg_tuple)) end)
	end

	@doc """
	* Lifts a binary function and applies it to two observables
	* Consumes processed values in a stream-wise fashion.
	This is similar to event-stream processing in FRP.
	"""
	def liftapp2_propagate(obs1, obs2, fun) do
		Obs.zip(obs1, obs2)
		|> Obs.map(fn {v1, v2} ->
			fun.(v1, v2) end)
	end

	@doc """
	* Lifts an n-ary function and applies it to a list of n observables.
	* Consumes processed values in a stream-wise fashion.
	This is similar to event-stream processing in FRP.
	"""
	def liftappn_propagate(obss, fun) do
		Obs.zip_n(obss)
		|> Obs.map(fn arg_tuple ->
			apply(fun, Tuple.to_list(arg_tuple)) end)
	end

	@doc """
	* Lifts an n-ary function and applies it to a list of n observables.
	* Does not consume processed values of observables in the first lsit, 
		but instead keeps them as state until a more recent value is received,
		Does not produce output when receiving a value of an observable in this list.
	* Consumes processed values of observables in the second list in a stream-wise fashion.
		Only when all observables of this list have a value available is an output produced
	"""
	def liftapp_update_propagate(obss1, obss2, fun) do
		Obs.combinelatest_n_zip_m(obss1, obss2)
		|> Obs.map(fn arg_tuple ->
			apply(fun, Tuple.to_list(arg_tuple)) end)
	end

	@doc """
	* Lifts an n-ary function and applies it to a list of n observables.
	* Does not consume processed values of observables in the first lsit, 
		but instead keeps them as state until a more recent value is received,
		Does not produce output when receiving a value of an observable in this list.
	* Consumes processed values of observables in the second list in a stream-wise fashion.
		Only when all observables of this list have a value available is an output produced
		Buffers last zipped values from this list so that they do not get lost in the absence
		of values from observables in the first list.
	"""
	def liftapp_update_propagate_buffered(obss1, obss2, fun) do
		Obs.combinelatest_n_zip_m_buffered(obss1, obss2)
		|> Obs.map(fn arg_tuple ->
			apply(fun, Tuple.to_list(arg_tuple)) end)
	end

	@doc """
	* Lifts an n-ary function and applies it to a list of n observables.
	* Does not consume processed values of observables in the first lsit, 
		but instead keeps them as state until a more recent value is received,
		Does not produce output when receiving a value of an observable in this list.
	* Consumes processed values of observables in the second list in a stream-wise fashion.
		Only when all observables of this list have a value available is an output produced
		Buffers last zipped values from this list so that they do not get lost in the absence
		of values from observables in the first list.
		When for all observables in the first list a value is received, the buffered zipped values
		are combined with these values until the buffer is empty.
	"""
	def liftapp_update_propagate_buffered_propagating(obss1, obss2, fun) do
		Obs.combinelatest_n_zip_m_buffered_propagating(obss1, obss2)
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
		Obs.combinelatest_var(obs, obss, inits)
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
	def liftappvar_propagate(obs, obss, fun) do
		Obs.zip_var(obs, obss)
		|> Obs.map(fn arg_tuple ->
			fun.(Tuple.to_list(arg_tuple)) end)
	end

end