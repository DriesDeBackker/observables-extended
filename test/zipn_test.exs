defmodule ZipnTest do
  use ExUnit.Case
  alias Observables.{Obs, Subject}
  require Logger

  @tag :zipn
  test "zipn" do
    testproc = self()

    xs = Subject.create()
    ys = Subject.create()
    zs = Subject.create()

    Obs.zipn([xs, ys, zs])
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

    # Send second value of xs, should not produce.
    Subject.next(xs, :x1)
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

    # Send third value of xs, should not produce.
    Subject.next(xs, :x2)
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

    # Send second value of zs, should not produce.
    Subject.next(zs, :z1)
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

    # Send second value of ys, should produce.
    Subject.next(ys, :y1)
    assert_receive({:x1, :y1, :z1}, 1000, "did not get this message!")

    # Send third value of ys, should not produce.
    Subject.next(ys, :y2)
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

    # Send third value of zs, should produce.
    Subject.next(zs, :z2)
    assert_receive({:x2, :y2, :z2}, 1000, "did not get this message!")

    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end
  end

end
