{:ok, _} = Application.ensure_all_started(:phoenix_live_view)
{:ok, _} = Application.ensure_all_started(:cachex)
{:ok, _} = Phoenix.PubSub.Supervisor.start_link(name: GridNest.TestPubSub)
{:ok, _} = GridNest.TestEndpoint.start_link()
{:ok, _} = Cachex.start_link(name: GridNest.LayoutStore.Cachex.cache_name())
{:ok, _} = GridNest.LayoutStore.Ets.start_link([])

ExUnit.start()
