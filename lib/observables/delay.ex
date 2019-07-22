defmodule Observables.Operator.Delay do
  @moduledoc false
  use Observables.GenObservable

  def init([interval]) do
    Logger.debug("Delay: #{inspect(self())}")
    {:ok, %{interval: interval, unsent: 0, done: false}}
  end

  # We have a value that must be emitted.
  def handle_event({:emit, v}, state = %{unsent: n, done: d}) do
    if {n, d} == {1, true} do
      Process.send_after(self(), :stop, 0)
    end
    {:value, v, %{state | unsent: n-1}}
  end

  # We received a value. Send it back to us after the delay interval is passed.
  def handle_event(v, state = %{unsent: n, interval: i}) do
    Process.send_after(self(), {:event, {:emit, v}}, i)
    {:novalue, %{state | unsent: n+1}}
  end

  def handle_done(pid, state = %{unsent: n}) do
    Logger.debug("#{inspect(self())}: dependency stopping: #{inspect(pid)}")
    case n do
      0 -> {:ok, :done}
      _ -> {:ok, :continue, :notermination, %{state | done: true}}
    end
  end
end
