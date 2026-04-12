defmodule GridNest.BrowserHash do
  @moduledoc """
  Server-side plumbing for the per-browser identifier used to key
  GridNest layouts.

  This module offers two integration points for host Phoenix apps that
  want the browser hash available at **first render**, before the JS
  hook has had a chance to hydrate:

    * `GridNest.BrowserHash.Plug` — a Plug that reads (or generates) a
      signed browser-hash cookie and both puts it in the session and
      assigns it to the `conn`. Mount this once in the pipeline that
      serves LiveViews.

    * `GridNest.BrowserHash.on_mount/4` — a LiveView `on_mount/4`
      callback that lifts the hash out of the session into
      `socket.assigns.grid_nest_browser_hash`. Register it in your
      `live_session` or `live` macros.

  Apps that don't care about first-render keying can skip this module
  entirely — the JS hook will generate and persist its own browser
  hash in localStorage and report it through the hydrate handshake.
  That path is still the authoritative one for EU opt-out, since no
  cookie is set when `client_storage: :none` is used.
  """

  @cookie_name "grid_nest_browser_hash"
  @session_key :grid_nest_browser_hash
  @assign_key :grid_nest_browser_hash

  @spec session_key() :: atom()
  def session_key, do: @session_key

  @spec cookie_name() :: String.t()
  def cookie_name, do: @cookie_name

  @spec on_mount(term(), map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()}
  def on_mount(_name, _params, session, socket) do
    hash = Map.get(session, Atom.to_string(@session_key), "")
    {:cont, Phoenix.Component.assign(socket, @assign_key, hash)}
  end

  defmodule Plug do
    @moduledoc """
    Plug that ensures every request has a `grid_nest_browser_hash`
    cookie, session entry and `conn.assigns.grid_nest_browser_hash`.

    Mount it in your router pipeline that serves LiveViews — **after**
    `:fetch_session` and `:fetch_cookies`:

        pipeline :browser do
          plug :accepts, ["html"]
          plug :fetch_session
          plug :fetch_live_flash
          plug GridNest.BrowserHash.Plug
          plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
          plug :protect_from_forgery
          plug :put_secure_browser_headers
        end
    """

    @behaviour Elixir.Plug

    import Elixir.Plug.Conn

    alias GridNest.BrowserHash

    @impl Elixir.Plug
    def init(opts), do: opts

    @impl Elixir.Plug
    def call(conn, _opts) do
      conn = fetch_cookies(conn)

      case Map.get(conn.req_cookies, BrowserHash.cookie_name()) do
        nil -> assign_new_hash(conn)
        existing -> reuse_hash(conn, existing)
      end
    end

    defp assign_new_hash(conn) do
      hash = generate_hash()

      conn
      |> put_session(BrowserHash.session_key(), hash)
      |> put_resp_cookie(BrowserHash.cookie_name(), hash,
        http_only: true,
        same_site: "Lax",
        max_age: 60 * 60 * 24 * 365 * 2
      )
      |> assign(:grid_nest_browser_hash, hash)
    end

    defp reuse_hash(conn, hash) do
      conn
      |> put_session(BrowserHash.session_key(), hash)
      |> assign(:grid_nest_browser_hash, hash)
    end

    defp generate_hash do
      :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
    end
  end
end
