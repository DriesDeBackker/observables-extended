defmodule CombineLatestSilentBufferedTest do
	use ExUnit.Case
  alias Observables.{Obs, Subject}
  require Logger

  @tag :combinelatestsilentbuffered
  test "Combine Latest Silent Buffered" do
    #           12          13    14     15
    # 1      2        3     			   4
    # =====================================
    # 							  12/1           14/2   

    testproc = self()

    # {:ok, pid1} = GenObservable.spawn_supervised(Observables.Subject)
    c = Subject.create()

    z = Subject.create()

    Obs.combinelatestsilent_buffered(c, z)
    |> Obs.map(fn v -> send(testproc, v) end)

    # Send first value from z, should not produce since no value from c yet.
    Subject.next(z, :z0)
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      100 -> :ok
    end

    # Send second value from z, should  not produce since no value from c yet.
    Subject.next(z, :z1)
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      100 -> :ok
    end

    # Send second value from c, should not produce, since silent
    Subject.next(c, :c0)
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      100 -> :ok
    end

    # Send third value from z, should produce with buffered value for z.
    Subject.next(z, :z2)
    assert_receive({:c0, :z0}, 5000, "did not get this message {:c0, :z0}!")

    # Update the c-observable, should be silent.
    Subject.next(c, :c1)
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      100 -> :ok
    end

    # Send fourth value from z, should produce with buffered value for z.
    Subject.next(z, :z3)
    assert_receive({:c1, :z1}, 5000, "did not get this message {:c1, :z1}!")

    Subject.next(z, :z4)
    assert_receive({:c1, :z2}, 5000, "did not get this message {:c1, :z2}!")

    # Mailbox should be empty.
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      100 -> :ok
    end
  end
end