metrics = [
  [:async_test]
]

Supervisor.start_link([TelemetryAsync.ShardSupervisor], strategy: :one_for_one)
Supervisor.start_link([{TelemetryAsync.Handler, metrics: metrics}], strategy: :one_for_one)

:telemetry.attach(
  :async_test,
  [:async, :async_test],
  fn a, b, c, d ->
    Process.sleep(1)
    # IO.inspect({a, b, c, d})
  end,
  nil
)

:telemetry.attach(
  :test,
  [:test],
  fn a, b, c, d ->
    Process.sleep(1)
    # IO.inspect({a, b, c, d})
  end,
  nil
)

defmodule LoadTest do
  def inline_load() do
    :timer.tc(fn ->
      worker_count = TelemetryAsync.ShardSupervisor.default_pool_size()
      per_worker = round(100_000 / worker_count)

      1..TelemetryAsync.ShardSupervisor.default_pool_size()
      |> Enum.map(fn _ ->
        Task.async(fn ->
          1..per_worker
          |> Enum.each(fn _ ->
            generate_request()
          end)
        end)
      end)
      |> Enum.each(&Task.await(&1, 60_000))
    end)
    |> IO.inspect()
  end

  def async_load() do
    :timer.tc(fn ->
      1..100_000
      |> Enum.each(fn _ ->
        generate_async_request()
      end)
    end)
    |> IO.inspect()
  end

  def generate_async_request() do
    :telemetry.execute([:async_test], payload(), %{})
  end

  def generate_request() do
    :telemetry.execute([:test], payload(), %{})
  end

  def payload() do
    Enum.reduce(1..40, %{}, fn i, acc ->
      Map.put(acc, i, make_ref() |> :erlang.term_to_binary())
    end)
  end
end

:observer.start()
Process.sleep(2000)
# LoadTest.inline_load()
LoadTest.async_load()
