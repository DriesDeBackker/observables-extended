defmodule Observables.Operator.Combine1Zip1 do
  @moduledoc false
  use Observables.GenObservable

  # silent == :left or :right
  def init([init]) do
    Logger.debug("Combine1Zip1: #{inspect(self())}")
    {:ok, {:c, init}}
  end

  def handle_event(value, {:c, c}=state) do
    case {value, c} do
      # We receive a value for the combination observable.
      {{:c, vc}, _} ->
        {:novalue, {:c, vc}}

      # We have no value for the combination observable 
      # but received a value for the zip observable.
      {{:z, _}, nil} ->
        {:novalue, state}

      # We do have a value for the combination observable 
      # and now received a value for the zip observable.
      {{:z, vz}, _} ->
        {:value, {c, vz}, {:c, c}}
    end
  end

  def handle_done(_pid, _state) do
    Logger.debug("#{inspect(self())}: Combine1Zip1 has one dead dependency, going on.")
    {:ok, :continue}
  end
end
