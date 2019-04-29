defmodule Observables.Operator.CombineLatestSilentBuffered do
  @moduledoc false
  use Observables.GenObservable

  # silent == :left or :right
  def init([init]) do
    Logger.debug("CombineLatestSilentBuffered: #{inspect(self())}")
    {:ok, {:c, init, :z, []}}
  end

  def handle_event(value, {:c, c, :z, zs}) do
    case {value, c, zs} do
      # We receive a value for the combination observable.
      {{:c, vc}, _, _} ->
        {:novalue, {:c, vc, :z, zs}}

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
    Logger.debug("#{inspect(self())}: CombineLatestSilentBuffered has one dead dependency, going on.")
    {:ok, :continue}
  end
end
