defmodule CombineLatestnTest do
  use ExUnit.Case
  alias Observables.{Obs, Subject}
  require Logger

  @tag :combinelatestn
  test "Combine Latest n" do
    testproc = self()

    xs = Subject.create()

    ys = Subject.create()

    zs = Subject.create()

    Obs.combinelatestn([xs, ys, zs])
    |> Obs.map(fn v -> send(testproc, v) end)

    # Send first value of xs, should not produce.
    Subject.next(xs, :x0)

    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

    # Send first value of ys, should not produce.
    Subject.next(ys, :y0)

    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

    # Send first value of zs, should produce.
    Subject.next(zs, :z0)
    assert_receive({:x0, :y0, :z0}, 1000, "did not get this message!")

    # Update the first observable. Should produce with history.
    Subject.next(xs, :x1)
    assert_receive({:x1, :y0, :z0}, 1000, "did not get this message!")

    # Update the second observable. Should produce with history.
    Subject.next(ys, :y1)
    assert_receive({:x1, :y1, :z0}, 1000, "did not get this message!")

    # Update the third observable. Should produce with history.
    Subject.next(zs, :z1)
    assert_receive({:x1, :y1, :z1}, 1000, "did not get this message!")

    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end
  end
end
