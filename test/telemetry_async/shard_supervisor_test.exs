defmodule TelemetryAsync.ShardSupervisorTest do
  use ExUnit.Case, async: false
  alias TelemetryAsync.ShardSupervisor

  describe "start_link/1" do
    test "a given number of shards are started under the supervisor" do
      assert {:ok, pid} = ShardSupervisor.start_link([])
      assert is_pid(pid)

      assert Supervisor.which_children(pid) |> length() == :erlang.system_info(:schedulers)
    end

    test "the pool size can be specified", %{test: test} do
      assert {:ok, pid} = ShardSupervisor.start_link(pool_size: 8, prefix: test)
      assert is_pid(pid)

      assert Supervisor.which_children(pid) |> length() == 8
      assert Supervisor.which_children(pid) |> List.first() |> elem(0) == :"#{test}_8"
      assert Supervisor.which_children(pid) |> List.last() |> elem(0) == :"#{test}_1"
    end

    test "the prefix can be specified", %{test: test} do
      assert {:ok, pid} = ShardSupervisor.start_link(prefix: test)
      assert is_pid(pid)

      assert Supervisor.which_children(pid) |> List.last() |> elem(0) == :"#{test}_1"
    end
  end
end
