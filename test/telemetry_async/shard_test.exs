defmodule TelemetryAsync.ShardTest do
  use ExUnit.Case, async: false
  require Logger
  import ExUnit.CaptureLog

  alias TelemetryAsync.Shard

  test "a Shard can be started", %{test: test} do
    assert {:ok, pid} = Shard.start_link(name: test)
    assert is_pid(pid)
  end

  test "a function can be executed in the Shard", %{test: test} do
    assert {:ok, pid} = Shard.start_link(name: test)

    assert capture_log(fn ->
             Shard.execute(pid, fn -> Logger.info("was here") end)
             Process.sleep(25)
           end) =~ "was here"
  end

  describe "name_for_number/2" do
    test "a name is generated for the number and prefix" do
      assert Shard.name_for_number(0, nil) == :"#{Shard}_0"
      assert Shard.name_for_number(1, nil) == :"#{Shard}_1"
      assert Shard.name_for_number(0, :prefix) == :prefix_0
    end
  end
end
