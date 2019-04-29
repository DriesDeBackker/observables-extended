defmodule Observables.Operator.CombineLatestSilentBufferedPropagating do
  @moduledoc false
  use Observables.GenObservable

  # silent == :left or :right
  def init([init]) do
    {:ok, {:c, init, :z, []}}
  end

  def handle_event(value, {:c, c, :z, zs}=state) do
    case {value, c, zs} do
      # We receive a value for the combination observable and we have no zip history.
      {{:c, vc}, _, []} ->
        {:novalue, {:c, vc, :z, []}}

      # We receive a value for the combination observable and we have a zip history.
      {{:c, vc}, _, [zh | zt]} ->
        Process.send(self(), {:event, :spit}, [])
        {:value, {vc, zh}, {:c, vc, :z, zt}}

      {:spit, _, [zh | zt]} ->
        Process.send(self(), {:event, :spit}, [])
        {:value, {c, zh}, {:c, c, :z, zt}}

      {:spit, _, []} ->
        {:novalue, state}

      # We have no value for the combination observable
      # and we received a value for the zip observable.
      {{:z, vz}, nil, _} ->
        {:novalue, {:c, c, :z, zs ++ [vz]}}

      # We do have a value for the combination observable, but not for the zip observable
      # and we received a value for the zip observable.
      {{:z, vz}, _, []} ->
        {:value, {c, vz}, {:c, c, :z, []}}

      # We have a value for both the combination observable and the zip observable
      # and we received a value for the zip observable.
      {{:z, vz}, _, [zh | zt]} ->
        {:value, {c, zh}, {:c, c, :z, zt ++ [vz]}}
    end
  end

  def handle_done(_pid, _state) do
    Logger.debug("#{inspect(self())}: CombineLatestSilentBufferedPropagating has one dead dependency, going on.")
    {:ok, :continue}
  end
end
