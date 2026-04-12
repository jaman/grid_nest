defmodule GridNest.LayoutStore.Noop do
  @moduledoc """
  Null adapter: accepts writes, forgets them, and always misses on reads.

  Use this when the host application wants a purely client-side board
  (client storage still works normally) or in tests as a drop-in stand-in
  for a real adapter.
  """

  @behaviour GridNest.LayoutStore

  alias GridNest.Layout.Key

  @impl true
  def load(%Key{}), do: :miss

  @impl true
  def load_any_browser(%Key{}), do: :miss

  @impl true
  def save(%Key{}, _layout), do: :ok

  @impl true
  def default(_page_key), do: []
end
