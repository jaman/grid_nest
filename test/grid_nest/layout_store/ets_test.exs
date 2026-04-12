defmodule GridNest.LayoutStore.EtsTest do
  use GridNest.LayoutStoreCase,
    adapter: GridNest.LayoutStore.Ets,
    supports: [:any_browser]

  alias GridNest.LayoutStore.Ets

  setup do
    Ets.reset!()
    :ok
  end
end
