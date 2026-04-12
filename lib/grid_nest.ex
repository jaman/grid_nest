defmodule GridNest do
  @moduledoc """
  LiveView-native draggable, resizable dashboard grids with pluggable
  client-side and server-side layout persistence.

  A `GridNest` layout is a list of `GridNest.Layout.Item` structs positioned
  on a column-based grid. Layouts are addressed by a `GridNest.Layout.Key`
  — the `{user_scope, page_key, browser_hash}` triple — so the same user
  can hold different layouts per device without merge conflicts.

  Persistence happens through two orthogonal axes:

    * **Server** — any module implementing `GridNest.LayoutStore`.
    * **Client** — a JS adapter (`localStorage`, `IndexedDB`, `none`) owned
      by the `GridNest.Board` hook.
  """
end
