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
    names = attach_metrics(metrics, pool_size, prefix)

    Process.flag(:trap_exit, true)

    {:ok, %{names: names, opts: opts}}
  end

  @doc false
  def handler(metric, measurements, metadata, %{pool_size: pool_size, prefix: prefix}) do
    ShardSupervisor.random_shard(pool_size: pool_size, prefix: prefix)
    |> Shard.execute(fn ->
      :telemetry.execute([:async | metric], measurements, metadata)
    end)
  end

  @doc false
  def terminate(_reason, %{names: names}) do
    Enum.each(names, fn metric ->
      :telemetry.detach(metric)
    end)
  end

  defp attach_metrics(metrics, pool_size, prefix) do
    Enum.map(metrics, fn metric ->
      name = [__MODULE__ | [prefix | metric]] |> Module.concat()

      :ok =
        :telemetry.attach(name, metric, &__MODULE__.handler/4, %{
          pool_size: pool_size,
          prefix: prefix
        })

      name
    end)
  end
end
