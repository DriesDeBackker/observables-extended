defmodule SwitchTest do
  use ExUnit.Case
  alias Observables.{Obs}
  require Logger

  @tag :switch1
  test "switch1" do
    Code.load_file("test/util.ex")
    testproc = self()

    s = Observables.Subject.create()

    s
    |> Obs.switch()
    |> Obs.map(fn v -> send(testproc, v) end)

    x =
      1..5
      |> Enum.to_list()
      |> Obs.from_enum()

    Logger.debug("Setting new observable x")
    Observables.Subject.next(s, x)
    Test.Util.sleep(10000)

    y =
      6..10
      |> Enum.to_list()
      |> Obs.from_enum()

    Logger.debug("Setting new observable y")
    Observables.Subject.next(s, y)

    1..10
    |> Enum.map(fn _x ->
      receive do
        v -> Logger.debug("Got #{v}")
      end
    end)

    assert 5 == 5
  end

  test "switch2" do
    testproc = self()

    s1 = Observables.Subject.create()
    s2 = Observables.Subject.create()
    s3 = Observables.Subject.create()
    sh = Observables.Subject.create()

    sr =
      s1
      |> Obs.switch(sh)
      |> Obs.map(fn v -> send(testproc, v) end)

    Observables.Subject.next(s2, :s2a)
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

    Observables.Subject.next(s3, :s3a)
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

    Observables.Subject.next(s1, :s1a)
    assert_receive(:s1a, 1000, "did not get this message!")
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

    Observables.Subject.next(s3, :s3b)
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

    Observables.Subject.next(s1, :s1b)
    assert_receive(:s1b, 1000, "did not get this message!")
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

    Logger.debug("Switching to second Subject")
    Observables.Subject.next(sh, s2)
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

    Observables.Subject.next(s1, :s1c)
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      100 -> :ok
    end

    Observables.Subject.next(s2, :s2b)
    assert_receive(:s2b, 1000, "did not get this message!")
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

    Observables.Subject.next(s3, :s3c)
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

    Observables.Subject.next(sh, s3)
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

    Observables.Subject.next(s2, :s2c)
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      100 -> :ok
    end

    Observables.Subject.next(s3, :s3d)
    assert_receive(:s3d, 1000, "did not get this message!")
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

    Observables.Subject.next(s1, :s1d)
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

    Observables.Subject.next(s2, :s2d)
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      1000 -> :ok
    end
  end
end
