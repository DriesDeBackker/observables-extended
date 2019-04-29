defmodule Observables.Operator.ZipVar do
  @moduledoc false
  use Observables.GenObservable
  alias Observables.Obs

	def init([pids_inds, obstp]) do
    Logger.debug("CombineLatestn: #{inspect(self())}")
    # Define the index for the next observable.
    index = length(pids_inds)
    # Unzip the indices for the initial observables.
    {_pids, inds} = Enum.unzip(pids_inds)
    # Create empty lists to store future values for the initial observables.
    queues = inds |> Enum.map(fn _ -> [] end)
    # Create a map that maps observable pids to their indices.
    indmap = pids_inds |> Map.new
    # Create a map that maps indices of observables to their value queues.
    qmap = Enum.zip(inds, queues) |> Map.new
    {:ok, {qmap, indmap, index, obstp}}
  end

  #Handle a new observable to listen to.
  def handle_event({:newobs, obs}, {qmap, indmap, index, obstp}) do
  	# Tag the new observable with a :newval tag and its newly given index so that we can process it properly.
  	{t_f, t_pid} = obs
  		|> Obs.map(fn val -> {:newval, index, val} end)
  	# Make the tagged observable send to us.
  	t_f.(self())
  	# Add the initial value as the entry for the new observable to the value map with its newly given index as the key.
		new_qmap = qmap |> Map.put(index, [])
		# Add the given index as the entry for the new observable to the index map with the pid of the tagged observable as its key.
		new_indmap = indmap |> Map.put(t_pid, index)
		# Increase the index counter
		new_index = index + 1
  	{:novalue, {new_qmap, new_indmap, new_index, obstp}}
  end
  #Handle a new value being sent to us from one of the observables we listen to.
  def handle_event({:newval, index, value}, {qmap, indmap, cindex, obstp}) do
  	# Update the queue of the observable by adding its newly received value to the back.
  	new_queue = Map.get(qmap, index) ++ [value]
  	new_qmap = %{qmap | index => new_queue}
    # Get the first value of every queue (represented as a list) or nil if that queue is empty.
  	firsts = new_qmap
  		|> Map.values
     	|> Enum.map(fn vs -> 
        if Enum.empty?(vs), do: :empty, else: List.first(vs) end)
    # Check if received from all dependencies.
    # If so, produce a new value from the first elements and pop these from their respective queues.
    if Enum.any?(firsts, fn fst -> fst == :empty end) do
  		{:novalue, {new_qmap, indmap, cindex, obstp}}
  	else
 			new_qmap
 				|> Enum.map(fn {index, queue} -> {index, Enum.drop(queue, 1)} end)
 				|> Map.new
  		{:value, List.to_tuple(firsts), {new_qmap, indmap, cindex, obstp}}
  	end
  end

  def handle_done(obstp, {qmap, indmap, cindex, obstp}) do
  	Logger.debug("#{inspect(self())}: zipvar has a dead observable stream, going on with possibility of termination.")
  	{:ok, :continue, {qmap, indmap, cindex, nil}}
  end
  def handle_done(pid, {qmap, indmap, cindex, nil}) do
  	Logger.debug("#{inspect(self())}: zipvar has one dead dependency and already a dead observable stream, going on with possibility of termination.")
  	index = Map.get(indmap, pid)
    new_indmap = Map.delete(indmap, pid)
    new_qmap = Map.delete(qmap, index)
  	{:ok, :continue, {new_qmap, new_indmap, cindex, nil}}
  end
  def handle_done(pid, {qmap, indmap, cindex, obstp}) do
    Logger.debug("#{inspect(self())}: zipvar has one dead dependency, but an active observable stream, going on without possibility of termination at this point.")
    index = Map.get(indmap, pid)
    new_indmap = Map.delete(indmap, pid)
    new_qmap = Map.delete(qmap, index)
    {:ok, :continue, :notermination, {new_qmap, new_indmap, cindex, obstp}}
  end
end