defmodule Observables.Operator.ZipN do
  @moduledoc false
  use Observables.GenObservable

  def init([n]) do
    Logger.debug("Zipn: #{inspect(self())}")
    inits = 1..n |> Enum.map(fn _ -> [] end)
    {:ok, inits}
  end

  def handle_event({index, value}, state) do
  	#Add the received value to the back of the list at the given index.
    new_state = state
   	|> List.update_at(index, fn vs -> vs ++ [value] end)
    #Get the first element of each list, which is :empty if the list is empty.
    firsts = new_state
   	|> Enum.map(fn vs -> 
      if Enum.empty?(vs), do: :empty, else: List.first(vs) end)
    #Check if received from all.
    #If so: produce a new value from the first elements and remove those from their respectivel ists.
    if Enum.any?(firsts, fn fst -> fst == :empty end) do
    	{:novalue, new_state}
   	else
   		new_state = new_state
 			|> Enum.map(fn vs -> Enum.drop(vs, 1) end)
    	{:value, List.to_tuple(firsts), new_state}
    end
  end

  def handle_done(_pid, _state) do
    Logger.debug("#{inspect(self())}: zipn has one dead dependency, stopping.")
    {:ok, :done}
  end
end
