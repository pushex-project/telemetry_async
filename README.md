# TelemetryAsync

[![Hex.pm](https://img.shields.io/hexpm/v/telemetry_async.svg)](https://hex.pm/packages/telemetry_async)
[![Hex.pm](https://img.shields.io/hexpm/dt/telemetry_async.svg)](https://hex.pm/packages/telemetry_async)
[![Hex.pm](https://img.shields.io/hexpm/l/telemetry_async.svg)](https://github.com/pushex-project/telemetry_async/blob/master/LICENSE)
[![Build Status](https://travis-ci.org/pushex-project/telemetry_async.svg?branch=master)](https://travis-ci.org/pushex-project/telemetry_async)

This library provides async execution of [telemetry](https://github.com/beam-telemetry/telemetry) events so that the
caller site is not blocked while your metrics are processed. This can be desirable if you have metrics that are in
your user impacting flow which could slow down your requests. Slow telemetry handlers, such as writing to a database,
can make this effect worse.

`TelemetryAsync` works by adding a handler to the metrics that you ask it to. It handles these events (ie. `[:a, :b]`) and
processes them in a sharded supervised process set. The process will execute the event under the name with `:async` prepended
(ie. `[:async, :a, :b]`).

You can customize the pool size or have multiple async pools running at once. The default pool size is the number of schedulers which
will help maximize the speed of processing the metrics.

## Installation

This package can be installed by adding `telemetry_async` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:telemetry_async, "~> 0.0.3"}
  ]
end
```

## Configuration

You must add a `TelemetryAsync.ShardSupervisor` and `TelemetryAsync.Handler` to your application (either in Application or
another Supervisor). This is to allow you to control the startup and shutdown of the processes. It is advised to start the
`ShardSupervisor` before the `Handler` so that the pool is ready when events process.

You can add it to your application like:

```elixir

  use Application

  def start(_type, _args) do
    children = [
      TelemetryAsync.ShardSupervisor,
      {
        TelemetryAsync.Handler,
        metrics: [
          [:metric_one],
          [:prefix, :metric_two]
        ]
      }
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
```

You can customize the `ShardSupervisor` and `Handler` by specifying the size of the execution pool and the prefix of the Shards. This
is useful if you want to have multiple Supervisors in your application. This is documented in the hexdocs.

The `Handler` will unsubscribe from all subscribed metrics when it terminates.

## Performance

The default `:telemetry` execution will run in the process of the caller. This means that no binaries are
copied. `TelemetryAsync`, however, will copy binaries (potentially large maps) due to crossing a process boundary.
Using synchronous handlers is probably useful for many people and you should go asynchronous only if you are
okay with the memory implications of it. In theory it will allow for higher throughput to your main processes (business requests)
and offload metrics to be async.

A way to help alleviate binary copying is provided. You are able to set `transform_fn` option on the `Handler` process.
This option will run the provided function for *every* execution it receives, before it crosses the process boundary.
You can return a tuple containing the new measurements and metadata like `{measurements, metadata}` and these will be
provided to `:telemetry.execute`. You must always provide a match, so the follow pattern is encouraged:

```elixir
defmodule TestTransform do
  def transform(
    [:metric_i_want_to_transform],
    measurements,
    %{some_metadata: %{nested: meta}}
  ) do
    {
      Map.take(measurements, [:key_i_care_about]),
      %{nested: meta}
    }
  end

  def transform([:removes, :everything], _a, _b) do
    {%{}, %{}}
  end

  def transform(_, a, b) do
    {a, b}
  end
end
```

This will allow you to utilize pattern matching on the metric names you care about (without `:async` added). You
can modify the payload or completely remove it by setting it to empty maps. A default case should be provided to
be an identity function.
