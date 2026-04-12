defmodule GridNest.TestEndpoint do
  @moduledoc """
  Minimal `Phoenix.Endpoint` used by the library's own LiveView tests.
  It has no routes and only exists so `Phoenix.LiveViewTest.live_isolated/3`
  has something to hang a socket off of.
  """

  use Phoenix.Endpoint, otp_app: :grid_nest

  @session_options [
    store: :cookie,
    key: "_grid_nest_test_key",
    signing_salt: "gridnest-test-salt",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Plug.Session, @session_options
end
