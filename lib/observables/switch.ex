defmodule Observables.Operator.Switch do
  @moduledoc false
  use Observables.GenObservable
  alias Observables.GenObservable
  alias Observables.Obs

  def init([init_obs]) do
    if init_obs == nil do
      {:ok, nil}
    else
      switcher = self()
      forwarder = init_obs
      |> Obs.map(fn v -> {:forward, v, init_obs} end)
      {forwarder_f, _forwarder_pid} = forwarder
      forwarder_f.(switcher)
      {:ok, {:forwarder, forwarder, :sender, init_obs}}
    end
  end

  def handle_event({:forward, v, sender}, {:forwarder, _forwarder, :sender, current_sender} = state) do
    if sender == current_sender do
      {:value, v, state}
    else
      {:novalue, state}
    end
  end

  def handle_event(new_obs, state) do
    switcher = self()

    # Unsubscribe to the previous observer we were forwarding.
    if state != nil do
      {:forwarder, forwarder, :sender, observable} = state
      {_f, pidf} = forwarder
      GenObservable.stop_send_to(pidf, self())
      {_f, pids} = observable
      GenObservable.stop_send_to(pids, pidf)
    end

    forwarder = new_obs
    |> Obs.map(fn v -> {:forward, v, new_obs} end)
    {forwarder_f, _forwarder_pid} = forwarder
    forwarder_f.(switcher)
    {:novalue, {:forwarder, forwarder, :sender, new_obs}}
  end

  def handle_done(_pid, _state) do
    {:ok, :continue}
  end
end
