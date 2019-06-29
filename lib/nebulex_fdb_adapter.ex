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

  alias FDB.{Directory, Transaction, Database, Future}
  alias FDB.Coder.{Subspace}

  @timeout 6000

  ## Adapter

  @impl true
  defmacro __before_compile__(env) do
    # TODO move to init
    :ok = FDB.start(610)
    cache = env.module
    config = Module.get_attribute(cache, :config)
    path = Keyword.fetch!(config, :db_path)
    cluster_file_path = Keyword.fetch!(config, :cluster_file_path)

    quote do
      def __db_path__, do: unquote(path)

      def __cluster_file_path__, do: unquote(cluster_file_path)

      def __db__ do
        :ets.lookup_element(:nebulex_fdb_adapter, :db, 2)
      end
    end
  end

  @impl true
  def init(opts) do
    cluster_file_path = Keyword.fetch!(opts, :cluster_file_path)
    db_path = Keyword.fetch!(opts, :db_path)

    db = Database.create(cluster_file_path)

    root = Directory.new()

    dir =
      Database.transact(db, fn tr ->
        Directory.create_or_open(root, tr, db_path)
      end)

    subspace = Subspace.new(dir)
    coder = Transaction.Coder.new(subspace)
    connected_db = Database.set_defaults(db, %{coder: coder})
    :ets.new(:nebulex_fdb_adapter, [:set, :public, {:write_concurrency, true}, {:read_concurrency, true}, :named_table])
    true = :ets.insert(:nebulex_fdb_adapter, {:db, connected_db})
    {:ok, []}
  end

  @impl true
  def get(cache, key, opts) do
    Task.async(fn ->
      :poolboy.transaction(
        :worker,
        fn pid -> GenServer.call(pid, {:get, cache, key, opts}) end,
        @timeout
      )
    end)
    |> Task.await(@timeout)
  end

  @impl true
  def get_many(cache, list, opts) do
    Task.async(fn ->
      :poolboy.transaction(
        :worker,
        fn pid -> GenServer.call(pid, {:get_many, cache, list, opts}) end,
        @timeout
      )
    end)
    |> Task.await(@timeout)
  end

  @impl true
  def set_many(cache, list, opts) do
    Task.async(fn ->
      :poolboy.transaction(
        :worker,
        fn pid -> GenServer.call(pid, {:set_many, cache, list, opts}) end,
        @timeout
      )
    end)
    |> Task.await(@timeout)
  end

  @impl true
  def has_key?(cache, key) do
    Task.async(fn ->
      :poolboy.transaction(
        :worker,
        fn pid -> GenServer.call(pid, {:has_key, cache, key}) end,
        @timeout
      )
    end)
    |> Task.await(@timeout)
  end

  @impl true
  def delete(cache, key, opts) do
    Task.async(fn ->
      :poolboy.transaction(
        :worker,
        fn pid -> GenServer.call(pid, {:delete, cache, key, opts}) end,
        @timeout
      )
    end)
    |> Task.await(@timeout)
  end

  @impl true
  def set(cache, obj, opts) do
    Task.async(fn ->
      :poolboy.transaction(
        :worker,
        fn pid -> GenServer.call(pid, {:set, cache, obj, opts}) end,
        @timeout
      )
    end)
    |> Task.await(@timeout)
  end

  @impl true
  def take(cache, key, _opts) do
    Task.async(fn ->
      :poolboy.transaction(
        :worker,
        fn pid -> GenServer.call(pid, {:take, cache, key}) end,
        @timeout
      )
    end)
    |> Task.await(@timeout)
  end

  @impl true
  def update_counter(cache, key, incr, _opts) do
    Task.async(fn ->
      :poolboy.transaction(
        :worker,
        fn pid -> GenServer.call(pid, {:update_counter, cache, key, incr, _opts}) end,
        @timeout
      )
    end)
    |> Task.await(@timeout)
  end

  @impl true
  def all(_cache, _query, _opts) do
    raise "Not Implemented."
  end

  @impl true
  def size(_cache) do
    raise "Not Implemented."
  end

  @impl true
  def flush(_cache) do
    raise "Not Implemented."
  end

  @impl true
  def expire(_cache, _key, _ttl) do
    raise "Not Implemented. Will be implemented on need."
  end

  @impl true
  def object_info(_cache, _key, _attr) do
    raise "Not Implemented. Will be implemented on need."
  end

  @impl true
  def stream(_cache, _query, _opts) do
    raise "Not Implemented. Will be implemented on need."
  end
end
