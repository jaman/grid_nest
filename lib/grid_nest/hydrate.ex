defmodule GridNest.Hydrate do
  @moduledoc """
  Pure resolver for the hydrate handshake that happens between
  `GridNest.Board`'s initial render and the JS hook's report of any
  client-side stored layout.

  Precedence rule (per project design):

    * If the hook reports a client layout, it wins — always.
    * If the hook reports nothing, we keep the server-resolved layout.

  Orthogonally, the decision also tells the Board whether the resolved
  layout needs to be written back to the server store. That happens
  when either:

    * the client layout replaced a server record (`:swap`), or
    * the server bootstrap fell through to `:default` or used the
      cross-browser `:server_any_browser` fallback — in both cases no
      record exists under the exact key yet, so we re-seed it with
      whatever we decided to render.
  """

  alias GridNest.Bootstrap.Result, as: BootstrapResult
  alias GridNest.Layout
  alias GridNest.Layout.Item

  defmodule Decision do
    @moduledoc """
    Outcome of `GridNest.Hydrate.resolve/2`.

      * `:layout` — the layout the Board should render after hydration.
      * `:action` — `:keep` if the render result is unchanged from the
        bootstrap, `:swap` if the client layout replaced it.
      * `:persist_to_server?` — whether the Board should call
        `LayoutStore.save/3` on the resolved layout.
    """

    @enforce_keys [:layout, :action, :persist_to_server?]
    defstruct [:layout, :action, :persist_to_server?]

    @type action :: :keep | :swap

    @type t :: %__MODULE__{
            layout: Layout.t(),
            action: action(),
            persist_to_server?: boolean()
          }
  end

  @spec resolve(BootstrapResult.t(), Layout.t() | nil) :: Decision.t()
  def resolve(%BootstrapResult{} = bootstrap, nil) do
    %Decision{
      layout: bootstrap.layout,
      action: :keep,
      persist_to_server?: needs_reseed?(bootstrap.source)
    }
  end

  def resolve(%BootstrapResult{layout: same} = bootstrap, same) do
    %Decision{
      layout: same,
      action: :keep,
      persist_to_server?: needs_reseed?(bootstrap.source)
    }
  end

  def resolve(%BootstrapResult{layout: bootstrap}, client_layout) when is_list(client_layout) do
    %Decision{
      layout: reapply_flags(client_layout, bootstrap),
      action: :swap,
      persist_to_server?: true
    }
  end

  defp needs_reseed?(:server_exact), do: false
  defp needs_reseed?(:server_any_browser), do: true
  defp needs_reseed?(:default), do: true

  defp reapply_flags(client_layout, bootstrap) do
    flags_by_id =
      Map.new(bootstrap, fn %Item{id: id, movable: movable, resizable: resizable} ->
        {id, {movable, resizable}}
      end)

    client_layout
    |> Enum.filter(fn %Item{id: id} -> Map.has_key?(flags_by_id, id) end)
    |> Enum.map(fn %Item{id: id} = item ->
      {movable, resizable} = Map.fetch!(flags_by_id, id)
      %Item{item | movable: movable, resizable: resizable}
    end)
  end
end
