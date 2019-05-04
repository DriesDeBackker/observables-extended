defmodule Observables.Operator.Rotate do
	@moduledoc false
  use Observables.GenObservable

  def init([n]) do
  	Logger.debug("Rotate: #{inspect(self())}")
  	buffer = 0..n-1
  	|> Enum.map(fn n -> {n, []} end)
  	|> Map.new
  	rotation = 0..n-1 
  	|> Enum.to_list
    {:ok, {:buffer, buffer, :rotation, rotation, :spitting, false}}
  end

  def handle_event({:newvalue, i, v}, {:buffer, b, :rotation, r, :spitting, s}) do
    case {r, s} do
    	{[^i | rt], false} ->
    		Process.send(self(), {:event, :spit}, [])
    		{:value, v, {:buffer, b, :rotation, rt ++ [i], :spitting, true}}

    	{[^i | _rt], true} ->
    		new_b = %{b | i => Map.get(b, i) ++ [v]}
    		{:novalue, {:buffer, new_b, :rotation, r, :spitting, true}}

    	{[_rh | _rt], _} ->
    		new_b = %{b | i => Map.get(b, i) ++ [v]}
    		{:novalue, {:buffer, new_b, :rotation, r, :spitting, s}}
    end
  end

  def handle_event(:spit, {:buffer, b, :rotation, [rh | rt]=r, :spitting, s}) do
  	case {b, s} do
  		{%{^rh => [qh | qt]}, true} ->
  			Process.send(self(), {:event, :spit}, [])
  			new_b = %{b | rh => qt}
  			{:value, qh, {:buffer, new_b, :rotation, rt ++ [rh], :spitting, true}}

  		{%{^rh => []}, true} -> 
  			{:novalue, {:buffer, b, :rotation, r, :spitting, false}}

  		{_, true} ->
  			Logger.error("Spitting should be true, but is false instead!")
  	end
  end

  def handle_done(_pid, _state) do
    Logger.debug("#{inspect(self())}: Rotate has one dead dependency, quitting.")
    {:ok, :done}
  end
end