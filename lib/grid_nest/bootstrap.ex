defmodule GridNest.Bootstrap do
  @moduledoc """
  Pure resolver that decides which layout `GridNest.Board` renders on
  its first connected mount, before any client hydrate has arrived.

  The resolver consults the configured server `LayoutStore` adapter
  through the following chain:

    1. Exact hit on `{user_scope, page_key, browser_hash}` — `:server_exact`.
    2. When `new_browser_fallback` is `:most_recent`, the most-recently
       saved layout for the same `{user_scope, page_key}` across any
       browser hash — `:server_any_browser`.
    3. Otherwise the caller-supplied `default_layout`, or the adapter's
       `default/1` if none was supplied — `:default`.

  The hydrate handshake may override this later when the client
  reports a locally stored layout; see `GridNest.Hydrate`.
  """

  alias GridNest.Layout
  alias GridNest.Layout.Key
  alias GridNest.LayoutStore

  defmodule Result do
    @moduledoc """
    Outcome of `GridNest.Bootstrap.resolve/1`.

      * `:layout` — the layout the LiveComponent should render initially.
      * `:source` — where the layout came from, useful for logging and
        for the Board to decide whether to re-seed the server store once
        a client hydrate confirms a value.
    """

    @enforce_keys [:layout, :source]
    defstruct [:layout, :source]

    @type source :: :server_exact | :server_any_browser | :default

    @type t :: %__MODULE__{
            layout: Layout.t(),
            source: source()
          }
  end

  @type fallback :: :most_recent | :default

  @type opts :: %{
          required(:adapter) => module(),
          required(:key) => Key.t(),
          required(:default_layout) => Layout.t() | nil,
          required(:new_browser_fallback) => fallback()
        }

  @spec resolve(opts()) :: Result.t()
  def resolve(%{new_browser_fallback: strategy} = opts)
      when strategy in [:most_recent, :default] do
    opts
    |> try_exact()
    |> maybe_try_any_browser(opts)
    |> maybe_fall_back(opts)
  end

  def resolve(%{new_browser_fallback: other}) do
    raise ArgumentError,
          "unknown new_browser_fallback strategy: #{inspect(other)} " <>
            "(expected :most_recent or :default)"
  end

  defp try_exact(%{adapter: adapter, key: key}) do
    case LayoutStore.load(adapter, key) do
      {:ok, layout} ->
        %Result{layout: layout, source: :server_exact}

      _miss_or_error ->
        nil
    end
  end

  defp maybe_try_any_browser(%Result{} = hit, _opts), do: hit

  defp maybe_try_any_browser(nil, %{new_browser_fallback: :default}), do: nil

  defp maybe_try_any_browser(nil, %{
         new_browser_fallback: :most_recent,
         adapter: adapter,
         key: key
       }) do
    wildcard = Key.any_browser(key.user_scope, key.page_key)

    case LayoutStore.load_any_browser(adapter, wildcard) do
      {:ok, layout} ->
        %Result{layout: layout, source: :server_any_browser}

      _miss_or_error ->
        nil
    end
  end

  defp maybe_fall_back(%Result{} = hit, _opts), do: hit

  defp maybe_fall_back(nil, %{adapter: adapter, default_layout: nil, key: key}) do
    %Result{
      layout: LayoutStore.default(adapter, key.page_key),
      source: :default
    }
  end

  defp maybe_fall_back(nil, %{default_layout: default}) when is_list(default) do
    %Result{layout: default, source: :default}
  end
end
