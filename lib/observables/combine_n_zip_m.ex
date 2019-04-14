defmodule Observables.Operator.CombineNZipM do
	@moduledoc false
  use Observables.GenObservable
  require Logger
  @docp """
  def init([c_inits, z_n]) do
    Logger.debug("CombineNZipM: #{inspect(self())}")
    z_inits = 1..n |> Enum.map(fn _ -> [] end)
    {:ok, {c_inits, z_inits}}
  end

  def handle_event({:combine, index, value}, {cs, zs}) do
  	prev_val = Enum.at(cs, index)
  	new_cs = cs |> List.replace_at(index, value)
  	firsts_zs = zs |> Enum.map(fn vs -> List.first(vs) end)
  	if prev_val == nil
  	and not Enum.any?(new_cs, fn v -> v == nil end)
  	and not Enum.any?(firsts_zs, fn v -> v == nil end) do
  		vals = new_cs ++ firsts_zs
  		{:value, List.to_tuple(vals), {new_cs, zs}}
  	else
  		{:novalue, new_state}
  	end
  end
  def handle_event({:zip, index, value}, {cs, zs}) do
  	new_zs = zs
     	|> List.update_at(index, fn vs -> vs ++ [value] end)
    #Get the first element of each list, which is nil if the list is empty.
    firsts = new_zs
     	|> Enum.map(fn vs -> List.first(vs) end)
    # Check if received from all.
    # If so: produce a new value from the first elements of the zips and the value sof the combines
    # and remove the first elements of the zip list.
    if Enum.any?(cs ++ firsts, fn v -> v == nil end) do
    	{:novalue, {cs, new_zs}}
   	else
   		new_state = new_state
   			|> Enum.map(fn vs -> Enum.drop(vs, 1) end)
    	{:value, List.to_tuple(firsts), new_state}
    end
  end

  def handle_done(_pid, _state) do
    Logger.debug("#{inspect(self())}: combinelatestn has one dead dependency, going on.")
    {:ok, :continue}
  end
  """
end