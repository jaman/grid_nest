defmodule GridNest.BoardHarness do
  @moduledoc """
  Minimal LiveView harness used by `GridNest.BoardTest` to mount the
  `GridNest.Board` LiveComponent in isolation.

  The harness exposes every Board prop as a query/session parameter so
  individual tests can configure the adapter, default layout, fallback
  strategy and browser hash without pulling in a real host app.
  """

  use Phoenix.LiveView

  alias GridNest.Board

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:user_scope, Map.fetch!(session, "user_scope"))
     |> assign(:page_key, Map.fetch!(session, "page_key"))
     |> assign(:browser_hash, Map.fetch!(session, "browser_hash"))
     |> assign(:server_storage, Map.fetch!(session, "server_storage"))
     |> assign(:client_storage, Map.fetch!(session, "client_storage"))
     |> assign(:default_layout, Map.fetch!(session, "default_layout"))
     |> assign(:new_browser_fallback, Map.fetch!(session, "new_browser_fallback"))
     |> assign(:collapse, Map.get(session, "collapse", :none))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      module={Board}
      id="test-board"
      user_scope={@user_scope}
      page_key={@page_key}
      browser_hash={@browser_hash}
      server_storage={@server_storage}
      client_storage={@client_storage}
      default_layout={@default_layout}
      new_browser_fallback={@new_browser_fallback}
      collapse={@collapse}
    />
    """
  end
end
