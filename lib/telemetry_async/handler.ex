defmodule TelemetryAsync.Handler do
  @moduledoc """
  GenServer that subscribes to the requested telemetry metrics. The handler will
  randomly distribute requests to the ShardSupervisor Shards and re-execute the telemetry
  metrics with :async prepended to the beginning.

  A metric like `[:test]` will become `[:async, :test]`

  The metrics are detached if the Handler process exits to allow graceful shutdown.
  """

  use GenServer

  alias TelemetryAsync.{Shard, ShardSupervisor}

  @doc """
  Starts the Telemetry.Handler. Several options are available:

  * metrics -(required) Must be provided. This is a list of telemetry metric names. They must be lists of atoms, like telemetry accepts
  * pool_size - (optional) The size of the ShardSupervisor pool. This defaults to the number of schedulers
  * prefix - (optional) An atom that is used to name the individual Shards. Defaults to `TelemetryAsync.Shard`
  * transform_fn - (optional) A function/3 that accepts the metric name (without async prepended), measurements, metadata and
                   returns a tuple `{measurements, metadata}` which will be executed async. This allows smaller data to cross
                   the process boundary. Like `:telemetry` recommends, it is recommended to provide a `&Module.function/3` capture
                   rather than providing an anonymous function.

  The prefix and pool_size should match a ShardSupervisor started with the same options or the telemetry events will not be re-broadcast.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc false
  def init(opts) do
    metrics = Keyword.fetch!(opts, :metrics)
    pool_size = Keyword.get(opts, :pool_size, ShardSupervisor.default_pool_size())
    prefix = Keyword.get(opts, :prefix, Shard.default_prefix())
    transform_fn = Keyword.get(opts, :transform_fn)
    names = attach_metrics(metrics, pool_size, prefix, transform_fn)

    Process.flag(:trap_exit, true)

    {:ok, %{names: names, opts: opts, transform_fn: transform_fn}}
  end

  @doc false
  def handler(metric, measurements, metadata, config = %{transform_fn: transform_fn})
      when is_function(transform_fn, 3) do
    {measurements, metadata} = transform_fn.(metric, measurements, metadata)
    exec_handler(metric, measurements, metadata, config)
  end

  def handler(metric, measurements, metadata, config) do
    exec_handler(metric, measurements, metadata, config)
  end

  @doc false
  def terminate(_reason, %{names: names}) do
    Enum.each(names, fn metric ->
      :telemetry.detach(metric)
    end)
  end

  defp exec_handler(metric, measurements, metadata, %{pool_size: pool_size, prefix: prefix}) do
    ShardSupervisor.random_shard(pool_size: pool_size, prefix: prefix)
    |> Shard.execute(fn ->
      :telemetry.execute([:async | metric], measurements, metadata)
    end)
  end

  defp attach_metrics(metrics, pool_size, prefix, transform_fn) do
    Enum.map(metrics, fn metric ->
      name = [__MODULE__ | [prefix | metric]] |> Module.concat()

      :ok =
        :telemetry.attach(name, metric, &__MODULE__.handler/4, %{
          pool_size: pool_size,
          prefix: prefix,
          transform_fn: transform_fn
        })

      name
    end)
  end
end
