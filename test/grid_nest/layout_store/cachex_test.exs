defmodule GridNest.LayoutStore.CachexTest do
  use GridNest.LayoutStoreCase,
    adapter: GridNest.LayoutStore.Cachex,
    supports: [:any_browser]

  alias GridNest.LayoutStore.Cachex, as: CachexStore

  setup do
    Cachex.clear!(CachexStore.cache_name())
    :ok
  end
end
