defmodule TelemetryAsync.HandlerTest do
  use ExUnit.Case, async: false
  require Logger
  import ExUnit.CaptureLog

  alias TelemetryAsync.{Handler, ShardSupervisor}

  describe "start_link/1" do
    test "a metric is attached to telemetry" do
      metric = [HandlerTest_1]

      assert :telemetry.list_handlers(metric) |> length() == 0
      assert {:ok, pid} = Handler.start_link(metrics: [metric])
      assert is_pid(pid)
      assert :telemetry.list_handlers(metric) |> length() == 1
    end

    test "multiple metrics are attached to telemetry" do
      metric = [HandlerTest_2]
      metric2 = [HandlerTest_3]

      assert :telemetry.list_handlers(metric) |> length() == 0
      assert :telemetry.list_handlers(metric2) |> length() == 0
      assert {:ok, pid} = Handler.start_link(metrics: [metric, metric2])
      assert is_pid(pid)
      assert :telemetry.list_handlers(metric) |> length() == 1
      assert :telemetry.list_handlers(metric2) |> length() == 1
    end
  end

  describe "handler" do
    test "the metric is dispatched as an async metric", %{test: test} do
      metric = [HandlerTest_4]
      assert {:ok, _sup_pid} = ShardSupervisor.start_link(prefix: test)
      assert {:ok, _pid} = Handler.start_link(metrics: [metric], prefix: test)

      assert :telemetry.attach(
               test,
               [:async | metric],
               fn a, b, c, d ->
                 assert a == [:async | metric]
                 assert b == %{a: 1}
                 assert c == %{b: 2}
                 assert d == nil
                 Logger.info(test)
               end,
               nil
             ) == :ok

      assert capture_log(fn ->
               assert :telemetry.execute(metric, %{a: 1}, %{b: 2}) == :ok
               Process.sleep(50)
             end) =~ to_string(test)
    end

    test "the metric is not dispatched if there is no shard supervisor", %{test: test} do
      metric = [HandlerTest_4]
      assert {:ok, _pid} = Handler.start_link(metrics: [metric], prefix: test)

      assert :telemetry.attach(
               test,
               [:async | metric],
               fn _, _, _, _ ->
                 Logger.info("fail")
               end,
               nil
             ) == :ok

      assert capture_log(fn ->
               assert :telemetry.execute(metric, %{a: 1}, %{b: 2}) == :ok
               Process.sleep(50)
             end) == ""
    end

    test "the metric is not dispatched if the handler is killed", %{test: test} do
      metric = [HandlerTest_5]
      assert {:ok, _sup_pid} = ShardSupervisor.start_link(prefix: test)
      assert {:ok, pid} = Handler.start_link(metrics: [metric], prefix: test)

      assert :telemetry.attach(
               test,
               [:async | metric],
               fn _, _, _, _ ->
                 Logger.info("fail")
               end,
               nil
             ) == :ok

      Process.exit(pid, :normal)

      assert capture_log(fn ->
               assert :telemetry.execute(metric, %{a: 1}, %{b: 2}) == :ok
               Process.sleep(50)
             end) == ""

      assert :telemetry.list_handlers(metric) |> length() == 0
    end
  end
end
