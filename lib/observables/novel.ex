defmodule Observables.Operator.Novel do
  @moduledoc false
  use Observables.GenObservable

  def init([comparator]) do
    Logger.debug("Distinct: #{inspect(self())}")
    {:ok, %{:comp => comparator, :last => nil}}
  end

  def handle_event(v, state = %{:comp => f, :last => x}) do
    repeat? = f.(v, x)

    if not repeat? do
      {:value, v, %{:comp => f, :last => v}}
    else
      {:novalue, state}
    end
  end

  def handle_done(pid, _state) do
    Logger.debug("#{inspect(self())}: dependency stopping: #{inspect(pid)}")
    {:ok, :continue}
  end
end
