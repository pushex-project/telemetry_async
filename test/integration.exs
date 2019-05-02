IO.puts("start")

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

Supervisor.start_link([TelemetryAsync.ShardSupervisor], strategy: :one_for_one)
Supervisor.start_link([{TelemetryAsync.Handler, metrics: metrics}], strategy: :one_for_one)

:telemetry.attach(
  :test,
  [:async, :test],
  fn a, b, c, d ->
    IO.inspect({a, b, c, d})
  end,
  nil
)

:telemetry.execute([:test], %{}, %{})

Process.sleep(100)

IO.puts("done")
