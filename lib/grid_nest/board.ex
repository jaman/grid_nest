defmodule GridNest.Board do
  @moduledoc """
  LiveComponent rendering a GridNest dashboard board.

  ## Props

    * `:id` — DOM id / LiveComponent id. Required.
    * `:user_scope` — opaque user identifier passed through to the
      `LayoutStore` adapter. Required.
    * `:page_key` — stable string identifying this board on the page.
      Required.
    * `:browser_hash` — per-browser identifier (the host app is
      responsible for pulling it out of session/cookie or passing `nil`
      so the hook can generate one on first paint). Required — pass the
      empty string when opting out of client storage.
    * `:server_storage` — module implementing `GridNest.LayoutStore`.
      Defaults to `GridNest.LayoutStore.Noop`.
    * `:client_storage` — `:local_storage`, `:indexed_db`, or `:none`.
      Controls which client adapter the JS hook picks. Defaults to
      `:local_storage`.
    * `:default_layout` — a `GridNest.Layout.t()` used when no stored
      record is found. Defaults to `nil` (the adapter's `default/1` is
      consulted instead).
    * `:new_browser_fallback` — `:most_recent` or `:default`. Controls
      what happens when a new `browser_hash` is seen for a user that
      already has layouts stored under other hashes. Defaults to
      `:most_recent`.
  """

  use Phoenix.LiveComponent

  alias GridNest.Bootstrap

  slot :tile,
    required: false,
    doc: "Optional slot rendered inside each tile. Receives the Layout.Item as :let."

  alias GridNest.Hydrate
  alias GridNest.Layout
  alias GridNest.Layout.Key
  alias GridNest.Layout.Mutate
  alias GridNest.LayoutStore

  @type assigns :: map()

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok,
     socket
     |> assign(:bootstrap_source, nil)
     |> assign(:layout, [])
     |> assign_new(:server_storage, fn -> GridNest.LayoutStore.Noop end)
     |> assign_new(:client_storage, fn -> :local_storage end)
     |> assign_new(:default_layout, fn -> nil end)
     |> assign_new(:new_browser_fallback, fn -> :most_recent end)
     |> assign_new(:tile, fn -> [] end)}
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if socket.assigns.bootstrap_source == nil do
      {:ok, bootstrap(socket)}
    else
      {:ok, socket}
    end
  end

  defp bootstrap(socket) do
    key = build_key(socket.assigns)

    result =
      Bootstrap.resolve(%{
        adapter: socket.assigns.server_storage,
        key: key,
        default_layout: socket.assigns.default_layout,
        new_browser_fallback: socket.assigns.new_browser_fallback
      })

    socket
    |> assign(:key, key)
    |> assign(:layout, result.layout)
    |> assign(:bootstrap_source, result.source)
    |> push_event("grid_nest:request_hydrate", %{
      id: socket.assigns.id,
      client_storage: socket.assigns.client_storage,
      page_key: socket.assigns.page_key
    })
  end

  @impl Phoenix.LiveComponent
  def handle_event("grid_nest:hydrate", %{"layout" => raw}, socket) do
    client_layout = decode_client_layout(raw)

    bootstrap = %Bootstrap.Result{
      layout: socket.assigns.layout,
      source: socket.assigns.bootstrap_source
    }

    decision = Hydrate.resolve(bootstrap, client_layout)

    if decision.persist_to_server? do
      _ = LayoutStore.save(socket.assigns.server_storage, socket.assigns.key, decision.layout)
    end

    {:noreply,
     socket
     |> assign(:layout, decision.layout)
     |> assign(:bootstrap_source, :server_exact)}
  end

  def handle_event("grid_nest:move", %{"id" => id, "x" => x, "y" => y}, socket)
      when is_binary(id) do
    coord = %{x: coerce_int(x), y: coerce_int(y)}

    case Mutate.move(socket.assigns.layout, id, coord) do
      {:ok, next_layout} -> {:noreply, commit_layout(socket, next_layout)}
      {:error, _reason} -> {:noreply, socket}
    end
  end

  def handle_event("grid_nest:resize", %{"id" => id, "w" => w, "h" => h}, socket)
      when is_binary(id) do
    size = %{w: coerce_int(w), h: coerce_int(h)}

    case Mutate.resize(socket.assigns.layout, id, size) do
      {:ok, next_layout} -> {:noreply, commit_layout(socket, next_layout)}
      {:error, _reason} -> {:noreply, socket}
    end
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="GridNestBoard"
      phx-target={@myself}
      data-page-key={@page_key}
      data-client-storage={to_string(@client_storage)}
      class="grid-nest-board"
      style="--grid-cols: 12; --grid-row-height: 60; --grid-gap: 8;"
    >
      <div
        :for={item <- @layout}
        id={"#{@id}-tile-#{item.id}"}
        data-grid-nest-tile
        data-id={item.id}
        data-x={item.x}
        data-y={item.y}
        data-w={item.w}
        data-h={item.h}
        data-movable={to_string(item.movable)}
        data-resizable={to_string(item.resizable)}
        class={tile_class(item)}
        style={tile_style(item)}
      >
        {render_slot(@tile, item)}
        <div :if={item.resizable} data-grid-nest-resize class="grid-nest-resize-handle"></div>
      </div>
    </div>
    """
  end

  @spec build_key(assigns()) :: Key.t()
  defp build_key(%{user_scope: scope, page_key: page, browser_hash: hash})
       when is_binary(hash) and hash != "" do
    Key.new(scope, page, hash)
  end

  defp build_key(%{user_scope: scope, page_key: page}) do
    Key.new(scope, page, "__no_browser__")
  end

  @spec tile_style(Layout.Item.t()) :: String.t()
  defp tile_style(%Layout.Item{x: x, y: y, w: w, h: h}) do
    "grid-column: #{x + 1} / span #{w}; grid-row: #{y + 1} / span #{h};"
  end

  @spec tile_class(Layout.Item.t()) :: String.t()
  defp tile_class(%Layout.Item{movable: true, resizable: true}), do: "grid-nest-tile"
  defp tile_class(%Layout.Item{}), do: "grid-nest-tile grid-nest-tile--locked"

  defp decode_client_layout(nil), do: nil
  defp decode_client_layout([]), do: nil

  defp decode_client_layout(list) when is_list(list) do
    case Layout.new(list) do
      {:ok, layout} -> layout
      {:error, _} -> nil
    end
  end

  defp commit_layout(socket, next_layout) do
    _ = LayoutStore.save(socket.assigns.server_storage, socket.assigns.key, next_layout)

    socket
    |> assign(:layout, next_layout)
    |> assign(:bootstrap_source, :server_exact)
    |> push_event("grid_nest:layout_saved", %{
      id: socket.assigns.id,
      layout: Layout.to_wire(next_layout)
    })
  end

  defp coerce_int(value) when is_integer(value), do: value
  defp coerce_int(value) when is_binary(value), do: String.to_integer(value)
end
