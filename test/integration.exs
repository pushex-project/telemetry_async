IO.puts("start")

defmodule TestTransform do
  def transform([:test], _a, _b) do
    {%{data: true}, %{transformed: true}}
  end

  def transform([:other, :test], _a, _b) do
    {%{other: true}, %{test: true}}
  end

  def transform(_, a, b) do
    {a, b}
  end
end

metrics = [
  [:test],
  [:other, :test],
  [:other, :test2]
]

# pool_size defaults to num schedulers
# prefix defaults to TelemetryAsync.Shard

Supervisor.start_link([{TelemetryAsync.ShardSupervisor, pool_size: 4, prefix: :steve}],
  strategy: :one_for_one
)

Supervisor.start_link([{TelemetryAsync.Handler, pool_size: 4, prefix: :steve, metrics: metrics}],
  strategy: :one_for_one
)

Supervisor.start_link([{TelemetryAsync.ShardSupervisor, pool_size: 4, prefix: :transformed}],
  strategy: :one_for_one
)

Supervisor.start_link(
  [
    {TelemetryAsync.Handler,
     pool_size: 4, prefix: :transformed, metrics: metrics, transform_fn: &TestTransform.transform/3}
  ],
  strategy: :one_for_one
)

Supervisor.start_link([TelemetryAsync.ShardSupervisor], strategy: :one_for_one)
Supervisor.start_link([{TelemetryAsync.Handler, metrics: metrics}], strategy: :one_for_one)

:telemetry.attach(:test, [:async, :test], fn a, b, c, d -> IO.inspect({a, b, c, d}) end, nil)
:telemetry.attach(:other_test, [:async, :other, :test], fn a, b, c, d -> IO.inspect({a, b, c, d}) end, nil)

:telemetry.execute([:test], %{a: 1}, %{b: 2})
:telemetry.execute([:other, :test], %{a: 1}, %{b: 2})

Process.sleep(100)

IO.puts("done")
