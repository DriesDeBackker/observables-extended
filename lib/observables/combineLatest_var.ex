defmodule Observables.Operator.CombineLatestVar do
  @moduledoc false
  use Observables.GenObservable
  alias Observables.Obs

  def init([pids, inits, obstp]) do
    Logger.debug("CombineLatestVar: #{inspect(self())}")
    # Define the index for the next observable.
    index = length(inits)
    # Create a map that maps observable pids to their indices.
    indmap = pids |> Map.new
    # Create a map that maps indices of observables to their current values.
    valmap = inits |> Map.new
    {:ok, {valmap, indmap, index, obstp}}
  end

  # Handle a new observable to listen to.
  def handle_event({:newobs, obs, init}, {valmap, indmap, index, obstp}) do
  	# Tag the new observable with a :newval tag and its newly given index so that we can process it properly.
  	{t_f, t_pid} = obs
  		|> Obs.map(fn val -> {:newval, index, val} end)
  	# Make the tagged observable send to us.
  	t_f.(self())
  	# Add the initial value as the entry for the new observable to the value map with its newly given index as the key.
		new_valmap = valmap |> Map.put(index, init)
		# Add the given index as the entry for the new observable to the index map with the pid of the tagged observable as its key.
		new_indmap = indmap |> Map.put(t_pid, index)
		# Increase the index counter
		new_index = index + 1
		# Produce a value with the initial value of the new observable if possible.
		vals = new_valmap |> Map.values
		if Enum.any?(vals, fn val -> val == nil end) do
  		{:novalue, {new_valmap, new_indmap, new_index, obstp}}
  	else
  		{:value, List.to_tuple(vals), {new_valmap, new_indmap, new_index, obstp}}
  	end
  end
  # Handle a new value being sent to us from one of the observables we listen to.
  def handle_event({:newval, index, value}, {valmap, indmap, cindex, obstp}) do
  	new_valmap = %{valmap | index => value}
  	vals = new_valmap |> Map.values
  	if Enum.any?(vals, fn val -> val == nil end) do
  		{:novalue, {new_valmap, indmap, cindex, obstp}}
  	else
  		{:value, List.to_tuple(vals), {new_valmap, indmap, cindex, obstp}}
  	end
  end

  def handle_done(obstp, {valmap, indmap, cindex, obstp}) do
  	Logger.debug("#{inspect(self())}: CombineLatestVar has a dead observable stream, going on with possibility of termination.")
  	{:ok, :continue, {valmap, indmap, cindex, nil}}
  end
  def handle_done(pid, {valmap, indmap, cindex, nil}) do
  	Logger.debug("#{inspect(self())}: CombineLatestVar has one dead dependency and already a dead observable stream, going on with possibility of termination.")
  	index = Map.get(indmap, pid)
    new_indmap = Map.delete(indmap, pid)
    new_valmap = Map.delete(valmap, index)
  	{:ok, :continue, {new_valmap, new_indmap, cindex, nil}}
  end
  def handle_done(pid, {valmap, indmap, cindex, obstp}) do
    Logger.debug("#{inspect(self())}: CombineLatestVar has one dead dependency, but an active observable stream, going on without possibility of termination at this point.")
    index = Map.get(indmap, pid)
    new_indmap = Map.delete(indmap, pid)
    new_valmap = Map.delete(valmap, index)
    {:ok, :continue, :notermination, {new_valmap, new_indmap, cindex, obstp}}
  end

end