import Config

config :grid_nest, GridNest.TestEndpoint,
  url: [host: "localhost"],
  secret_key_base: String.duplicate("a", 64),
  live_view: [signing_salt: "gridnest-test-lv"],
  check_origin: false,
  server: false,
  pubsub_server: GridNest.TestPubSub,
  render_errors: [formats: [html: Phoenix.Controller.Render.HTML]]

config :phoenix, :json_library, Jason
