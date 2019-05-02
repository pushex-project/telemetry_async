defmodule TelemetryAsync.ShardSupervisor do
  @moduledoc """
  Supervisor that manages the Shards. The requested number of shards will be started with the
  specified prefix
  """

  use Supervisor

  alias TelemetryAsync.Shard

  @doc false
  def random_shard(opts \\ []) do
    prefix = Keyword.get(opts, :prefix)
    num_shards = Keyword.get(opts, :pool_size, default_pool_size())

    :rand.uniform(num_shards)
    |> Shard.name_for_number(prefix)
    |> Process.whereis()
  end

  @doc """
  Starts the ShardSupervisor. There are several options available:

  * prefix - (optional) An atom that is used to name the individual Shards. Defaults to `TelemetryAsync.Shard`
  * pool_size - (optional) The size of the ShardSupervisor pool. This defaults to the number of schedulers
  """
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def init(opts) do
    shard_prefix = Keyword.get(opts, :prefix)
    num_shards = Keyword.get(opts, :pool_size, default_pool_size())

    shards =
      for n <- 1..num_shards do
        shard_name = Shard.name_for_number(n, shard_prefix)
        worker(Shard, [[name: shard_name]], id: shard_name)
      end

    supervise(shards, strategy: :one_for_one)
  end

  @doc false
  def default_pool_size(), do: :erlang.system_info(:schedulers)
end
