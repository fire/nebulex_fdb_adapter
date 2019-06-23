defmodule NebulexFdbAdapter do
  @moduledoc """
  Documentation for NebulexFdbAdapter.
  """

  # Inherit default transaction implementation
  use Nebulex.Adapter.Transaction

  # Provide Cache Implementation
  @behaviour Nebulex.Adapter
  @behaviour Nebulex.Adapter.Queryable

  alias Nebulex.Object

  alias FDB.{Directory, Transaction, Database}
  alias FDB.Coder.{Subspace}

  ## Adapter

  @impl true
  defmacro __before_compile__(env) do
    cache = env.module
    config = Module.get_attribute(cache, :config)
    path = Keyword.fetch!(config, :db_path)
    cluster_file_path = Keyword.fetch!(config, :cluster_file_path)

    quote do
      def __db_path__, do: unquote(path)

      def __cluster_file_path__, do: unquote(cluster_file_path)

      def __db__ do
        :ets.lookup_element(:meta, :db, 2)
      end
    end
  end

  @impl true
  def init(opts) do
    :meta = :ets.new(__MODULE__, [:named_table, :public, {:readd_concurrency, true}])
    :ok = FDB.start(610)
    cluster_file_path = Keyword.fetch!(opts, :cluster_file_path)
    db_path = Keyword.fetch!(opts, :db_path)

    db =
      FDB.Cluster.create(cluster_file_path)
      |> FDB.Database.create()
    root = Directory.new()
    dir =
      Database.transact(db, fn tr ->
        Directory.create_or_open(root, tr, db_path)
      end)
    test_dir = Subspace.new(dir)
    coder = Transaction.Coder.new(test_dir)
    connected_db = FDB.Database.set_defaults(db, %{coder: coder})
    true = :ets.insert(__MODULE__, {:db, connected_db})
    {:ok, []}
  end

  @impl true
  def get(_cache, key, opts) do
    db = Keyword.fetch!(opts, :db)
    FDB.Database.transact(
      db,
      fn transaction ->
        FDB.Transaction.get(transaction, key)
      end
    )
  end

  @impl true
  def set(_cache, %Object{key: key, value: value}, opts) do
    db = Keyword.fetch!(opts, :db)
    FDB.Database.transact(
      db,
      fn transaction ->
        FDB.Transaction.set(transaction, key, value)
      end
    )
  end

  # FDB.Database.transact(connected_db ,
  # fn transaction ->
  #   FDB.Transaction.clear(transaction, "key")
  # end
  # )

  # Database.transact(db, fn tr ->
  #   Directory.list(root, tr, ["nebulex"])
  # end)
end
