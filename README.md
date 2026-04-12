# GridNest

A drag-and-drop, resize-and-reflow tile board for Phoenix LiveView.
Small, server-authoritative, and free of runtime JavaScript dependencies
outside the single hook that ships with the library.

- Server-side layout state in Elixir structs, with pluggable persistence.
- A 12-column (configurable) CSS grid driven by custom properties.
- Collision cascading: drop a tile, colliding neighbours push out of the
  way. Moves that would displace a locked tile are rejected.
- Per-tile `movable` / `resizable` flags so you can pin header banners,
  sidebars, or any tile that should never shuffle.
- Opt-in drag handles: mark any child element with
  `data-grid-nest-drag-handle` to restrict the drag surface to a header
  bar and keep the rest of the tile free for its own interactions.
- Optional client-side layout mirror via `localStorage` or `IndexedDB`,
  with a clear pre-consent default for jurisdictions that require
  opt-in for terminal storage.
- No trailing transitions, no drop flash, no lag — `pushEventTo` with a
  reply callback keeps the drop snap clean.

## Installation

Add the library to your `mix.exs`:

```elixir
def deps do
  [
    {:grid_nest, "~> 0.1.0"}
  ]
end
```

Then run the installer. It copies the JS hook and CSS into
`assets/vendor/` and patches `assets/js/app.js` to register the hook:

```bash
mix grid_nest.install
```

The installer also writes a short `priv/grid_nest/INSTALL.md` describing
any manual follow-up steps (hook registration, mounting the component).

Finally, `@import "../vendor/grid_nest.css"` from your app's main CSS
file (this is done automatically by the installer for fresh Phoenix
projects, but worth double-checking for existing apps).

### Add the storage adapter to your supervision tree

GridNest deliberately does **not** start any runtime processes on its
own — the host app owns the supervision tree. If you use an adapter
that needs a long-lived process (`Ets`, `Dets`, `Cachex`), add it to
your own `application.ex`:

```elixir
# lib/my_app/application.ex
def start(_type, _args) do
  children = [
    # ... your other children
    GridNest.LayoutStore.Ets
  ]

  Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
end
```

`GridNest.LayoutStore.Noop` is process-less and needs no supervision.
Custom adapters backed by your own Ecto/Ash domain typically piggy-back
on the Repo/domain process you already supervise.

## Quick start

Mount the board as a `Phoenix.LiveComponent` in any LiveView template:

```heex
<.live_component
  module={GridNest.Board}
  id="dashboard"
  user_scope={@current_user.id}
  page_key="home"
  browser_hash={@browser_hash}
  server_storage={GridNest.LayoutStore.Ets}
  client_storage={:none}
  default_layout={default_layout()}
  new_browser_fallback={:most_recent}
>
  <:tile :let={item}>
    <.tile_body id={item.id} />
  </:tile>
</.live_component>
```

Define a default layout in plain Elixir:

```elixir
defp default_layout do
  GridNest.Layout.new!([
    %{id: "banner",  x: 0, y: 0, w: 12, h: 2, movable: false, resizable: false},
    %{id: "revenue", x: 0, y: 2, w: 6,  h: 4},
    %{id: "latency", x: 6, y: 2, w: 6,  h: 4},
    %{id: "errors",  x: 0, y: 6, w: 4,  h: 3},
    %{id: "users",   x: 4, y: 6, w: 4,  h: 3},
    %{id: "queue",   x: 8, y: 6, w: 4,  h: 3}
  ])
end
```

That's it — tiles are draggable and resizable, the banner is pinned,
and the layout persists server-side through `GridNest.LayoutStore.Ets`.

## `GridNest.Board` props

| Prop                   | Required | Description                                                                     |
| ---------------------- | :------: | ------------------------------------------------------------------------------- |
| `id`                   |    ✓     | DOM id / `LiveComponent` id.                                                    |
| `user_scope`           |    ✓     | Opaque per-user identifier passed through to the storage adapter.               |
| `page_key`             |    ✓     | Stable string identifying this board on the page (e.g. `"home"`, `"admin"`).    |
| `browser_hash`         |    ✓     | Per-browser identifier or `""` to opt out of browser-specific storage.          |
| `server_storage`       |          | Module implementing `GridNest.LayoutStore`. Defaults to `...LayoutStore.Noop`.  |
| `client_storage`       |          | `:none` (default), `:local_storage`, or `:indexed_db`.                          |
| `default_layout`       |          | `GridNest.Layout.t()` used when no stored record is found. Defaults to `nil`.   |
| `new_browser_fallback` |          | `:most_recent` (default) or `:default`. Controls first-paint for new browsers.  |

## Tiles and the `:tile` slot

The `:tile` slot receives a `GridNest.Layout.Item` struct as `:let`,
and you render whatever component you want inside each tile. The outer
`.grid-nest-tile` wrapper, the drag-handle cursor, and the resize
handle are all handled by the library.

```heex
<:tile :let={item}>
  <div class="rounded-lg bg-white p-4 shadow">
    <h3>{item.id}</h3>
  </div>
</:tile>
```

## Drag handles — restricting the drag surface

By default, the **whole tile** is the drag surface — clicking anywhere
inside a tile (except on the resize handle) starts a drag. For tiles
with interactive content (buttons, charts, tables, form inputs) you
often want dragging to only start from a specific element like a
header bar.

Mark any element inside your `:tile` slot with
`data-grid-nest-drag-handle` and GridNest will:

1. Only start a drag when the pointer is **inside** that element.
2. Leave the rest of the tile free for its own interactions.
3. Show the `grab` cursor on the handle (and `grabbing` while dragging).

A tile can only *have* a drag handle or *be* a drag surface — as soon
as any descendant carries the attribute, the whole-tile drag mode
turns off for that tile.

```heex
<:tile :let={item}>
  <div class="flex h-full w-full flex-col rounded-lg bg-base-100 shadow">
    <!-- Drag handle: the header bar -->
    <div data-grid-nest-drag-handle class="border-b p-3 font-semibold">
      {item.id}
    </div>

    <!-- Interactive body: NOT a drag surface -->
    <div class="min-h-0 flex-1 overflow-y-auto p-3">
      <button phx-click="do-thing">Click me without starting a drag</button>
      <ul>…</ul>
    </div>
  </div>
</:tile>
```

The resize handle (bottom-right corner) is unaffected and keeps
working regardless of the drag-handle configuration.

### A note on flex content that might overflow

If your tile's body uses a flex column with a `flex-1` child that
contains an intrinsically sized element (an SVG chart, a table), add
`min-h-0 overflow-hidden` to the flex-1 child. Flex items default to
`min-height: auto` (their content's min-content), which can cause
children to overflow their flex container. The library applies
`overflow: hidden` to `.grid-nest-tile` itself as a safety net — any
overflow is clipped at the tile boundary rather than leaking into
neighbouring tiles and hijacking their pointer events — but getting
`min-h-0` right at the flex layer is still best practice.

## Locking tiles — `movable` and `resizable`

Every `GridNest.Layout.Item` accepts two optional boolean flags, both
defaulting to `true`:

- **`movable: false`** — the tile cannot be dragged by the user, **and**
  collision cascades will not push it aside. It acts as a wall. Any
  drag or resize that would displace it is rejected at the server and
  visually reverts on the client.
- **`resizable: false`** — the resize handle is not rendered and the
  tile cannot be resized. Useful for tiles whose dimensions are
  semantically fixed (full-width banners, sidebars, pinned header rows).

Example:

```elixir
%{id: "banner", x: 0, y: 0, w: 12, h: 2, movable: false, resizable: false}
```

Flags are **structural**: they come from the developer-defined
`default_layout` and are reapplied on every hydrate so a stale or
tampered `localStorage` entry can never promote a locked tile back to
interactive.

## Layout data model

```elixir
%GridNest.Layout.Item{
  id: "revenue",
  x: 0, y: 2,       # zero-based grid cell origin
  w: 6, h: 4,       # span in grid cells
  movable: true,
  resizable: true
}
```

- A `GridNest.Layout.t()` is just a list of `Layout.Item.t()` with
  unique ids and no overlapping footprints.
- `GridNest.Layout.new/1` validates those invariants.
- `GridNest.Layout.Mutate.move/3`, `resize/3`, and `compact/1` are the
  pure functions behind the live component's move/resize events.

## Server-side storage adapters

`GridNest.LayoutStore` is a behaviour with four callbacks: `load/1`,
`load_any_browser/1`, `save/2`, and `default/1`. The library ships
several implementations:

| Adapter                          | Notes                                                                 |
| -------------------------------- | --------------------------------------------------------------------- |
| `GridNest.LayoutStore.Noop`      | Default. Stores nothing. Useful for anonymous demos and tests.        |
| `GridNest.LayoutStore.Ets`       | In-memory ETS table owned by a supervised `GenServer`. Ephemeral.     |
| `GridNest.LayoutStore.Dets`      | ETS with DETS backup. Survives app restart.                           |
| `GridNest.LayoutStore.Cachex`    | Delegates to a configured [Cachex](https://hexdocs.pm/cachex) cache.  |

Writing your own adapter is a matter of implementing the four
callbacks — see `lib/grid_nest/layout_store.ex` for the contract and
the shipped adapters for examples. If you run an Ash project,
`mix grid_nest.install --with-ash-store` scaffolds a stub module ready
to be wired up to an Ash resource.

## Client-side storage — and why you should probably start with `:none`

The JS hook can optionally mirror the authoritative server layout into
the user's browser via `localStorage` or `IndexedDB`. This is a pure
performance/UX optimisation: it lets a returning user see their most
recent layout **instantly** on first paint, before the server round
trip that would otherwise load it from `server_storage`.

Controlled via the `client_storage` prop on `GridNest.Board`:

- `:none` (default) — the hook never reads or writes `localStorage`.
  Safe in every jurisdiction, pre-consent, and for SSR-first pages.
- `:local_storage` — mirrors the layout into `localStorage` keyed by a
  random per-browser UUID. **Requires consent in the EU and UK** (see
  below).
- `:indexed_db` — currently delegates to the same `localStorage`
  backend; reserved for a future true IndexedDB adapter.

### Privacy, EU cookie law, and GDPR

> *This section is a plain-language summary intended to help developers
> reason about their obligations. It is not legal advice — talk to your
> own lawyer before shipping to EU or UK users.*

When `client_storage: :local_storage` is active and the user first
interacts with the board, the hook writes two things into their
browser:

1. **`grid_nest:browser_hash`** — a random UUID (generated via
   `crypto.randomUUID()`). Used to key which layout belongs to which
   browser.
2. **`grid_nest:layout:<board-id>:<page-key>:<hash>`** — the
   serialized tile positions for that board on that page.

Writes are **lazy**: nothing is written until a layout mutation
actually occurs. Opening the page without interacting produces zero
writes. Reads on mount happen only if a value is already present.

The ePrivacy Directive (2002/58/EC, Art. 5(3)) — the legal basis for
"cookie banners" — applies to **any** storage in the user's terminal
equipment, not just HTTP cookies. `localStorage` and `IndexedDB` are
both explicitly covered. The only exemptions are:

- Storage strictly necessary for a service the user *explicitly*
  requested, and
- Transmission over a communication network.

A persistent cross-session UUID used for layout memory does not
cleanly fit either exemption. In practice this means: **if you enable
`:local_storage` and you serve EU or UK users, you need to obtain
opt-in consent before the hook starts writing.**

GridNest does not ship a consent banner and will not pretend to make
compliance decisions for you. What it *does* give you:

- A pre-consent-safe default (`client_storage: :none`) that touches
  nothing.
- A lazy write path — no writes occur until the user actually moves or
  resizes a tile, and browser hash generation is deferred until then.
- A `clearLocalLayouts/0` helper exported from `grid_nest.js` that
  wipes every `grid_nest:*` key from `localStorage`. Call it from your
  own "withdraw consent" flow:

  ```js
  import { clearLocalLayouts } from "../vendor/grid_nest.js"

  document.querySelector("#withdraw-consent").addEventListener("click", () => {
    clearLocalLayouts()
  })
  ```

**Typical integration pattern:**

1. Start the board with `client_storage: :none`. This is the initial
   render and is safe everywhere.
2. When your own consent UI reports that the user has accepted
   storage, re-render the LiveView with `client_storage: :local_storage`
   (e.g. via a `handle_info` that assigns a new value). The hook will
   remount with the new adapter and begin mirroring.
3. On withdrawal, re-render with `:none` and call `clearLocalLayouts()`
   from the host app.

**Server-side storage** (ETS, DETS, Cachex, a custom Ash adapter) is a
GDPR question orthogonal to the ePrivacy cookie concern. Whatever you
persist server-side against a `user_scope` is personal data under
GDPR if the scope is tied to an identifiable person — disclose it in
your host app's privacy notice and handle subject-access/erasure
requests through your normal mechanism.

### What GridNest does **not** do

- It does not ship a consent banner.
- It does not attempt to auto-detect jurisdiction.
- It does not define what "consent" means for your users (age,
  jurisdiction, accessibility needs, and so on).
- It does not persist any analytics, telemetry, or fingerprints.

## Styling

The library ships a single `.grid-nest-board` rule that drives the
actual CSS Grid tracks from three custom properties:

- `--grid-cols` (default `12`)
- `--grid-row-height` (default `60`, in pixels)
- `--grid-gap` (default `8`, in pixels)

The `GridNest.Board` component emits those as inline style on the
container. If you want a different column count or row height, set
them on a parent rule or directly on the board via your own CSS.

Tile appearance is driven by three classes:

- `.grid-nest-tile` — base tile wrapper. `min-width: 0` and
  `min-height: 0` prevent inline resize previews from bleeding into
  grid track sizing.
- `.grid-nest-tile--dragging` — added during an active drag. Bumps
  `z-index`, suppresses transitions, and shows a drop shadow.
- `.grid-nest-tile--locked` — added when either `movable` or
  `resizable` is false. Default cursor instead of `grab`.

All three are overridable via custom properties — see
`assets/css/grid_nest.css` for the full list.

## Persistence across restarts

| server_storage      | survives app restart? | survives node restart? |
| ------------------- | :-------------------: | :--------------------: |
| `Noop`              |          no           |           no           |
| `Ets`               |          no           |           no           |
| `Dets`              |          yes          |           yes          |
| `Cachex`            | depends on Cachex     | depends on Cachex      |
| custom (Ash, Ecto)  |          yes          |           yes          |

For most production apps where layouts are per-user and need to
survive restarts, a custom adapter backed by your existing
data layer (Ash, Ecto) is the right choice.

## Contributing

The library has a thorough test suite:

```bash
mix test           # ExUnit + LiveView harness tests
mix credo --strict
mix format --check-formatted
```

Issues and PRs welcome.

## License

MIT.
