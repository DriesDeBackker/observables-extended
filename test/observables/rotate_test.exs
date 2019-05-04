defmodule RotateTest do
	use ExUnit.Case
	alias Observables.{Obs, Subject}

	test "rotate" do
		testproc = self()

		a = Subject.create
		b = Subject.create
		c = Subject.create

		Obs.rotate([a, b, c])
		|> Obs.each(fn v -> send(testproc, v) end)
		|> Obs.inspect

		Subject.next(b, :b1)
		receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

    Subject.next(c, :c1)
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

		Subject.next(b, :b2)
		receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

    Subject.next(a, :a1)
    assert_receive(:a1, 1000, "did not get this message!")
    assert_receive(:b1, 1000, "did not get this message!")
    assert_receive(:c1, 1000, "did not get this message!")
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

    Subject.next(a, :a2)
    assert_receive(:a2, 1000, "did not get this message!")
    assert_receive(:b2, 1000, "did not get this message!")
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

    Subject.next(c, :c2)
    assert_receive(:c2, 1000, "did not get this message!")
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

    Subject.next(b, :b3)
    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      0 -> :ok
    end

    Subject.next(a, :a3)
    assert_receive(:a3, 1000, "did not get this message!")
		assert_receive(:b3, 1000, "did not get this message!")
		receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      200 -> :ok
    end
	end
end