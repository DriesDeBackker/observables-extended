defmodule NovelTest do
  use ExUnit.Case
  alias Observables.{Obs}
  require Logger

  @tag :novel
  test "Novel" do
    testproc = self()

    xs = [1, 1, 1, 1, 2, 2, 1, 1, 3]

    xs
    |> Obs.from_enum(100)
    |> Obs.novel()
    |> Obs.map(fn v -> send(testproc, v) end)

    [1, 2, 1, 3]
    |> Enum.map(
      fn x ->
        receive do
          ^x -> :ok
          _ -> assert false
        end
      end)

    receive do
      x -> flunk("Mailbox was supposed to be empty, got: #{inspect(x)}")
    after
      500 -> :ok
    end

    assert true
  end
end
