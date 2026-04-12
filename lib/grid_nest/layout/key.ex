defmodule GridNest.Layout.Key do
  @moduledoc """
  Address of a stored layout.

  A key is the triple `{user_scope, page_key, browser_hash}`:

    * `user_scope` — whatever the host app uses to identify a user (an
      integer, UUID string, `{:guest, token}` tuple, …). Opaque to GridNest.
    * `page_key` — a stable string identifying *which* board on the page,
      e.g. `"home"`, `"settings/usage"`.
    * `browser_hash` — per-browser identifier generated client-side, so
      that mobile vs. desktop vs. 4K monitor layouts stay independent.
      `:any` is a wildcard used by fallback lookups.
  """

  @enforce_keys [:user_scope, :page_key, :browser_hash]
  defstruct [:user_scope, :page_key, :browser_hash]

  @type user_scope :: term()
  @type page_key :: String.t()
  @type browser_hash :: String.t() | :any

  @type t :: %__MODULE__{
          user_scope: user_scope(),
          page_key: page_key(),
          browser_hash: browser_hash()
        }

  @spec new(user_scope(), page_key(), String.t()) :: t()
  def new(user_scope, page_key, browser_hash)
      when is_binary(page_key) and is_binary(browser_hash) do
    %__MODULE__{
      user_scope: user_scope,
      page_key: page_key,
      browser_hash: browser_hash
    }
  end

  def new(_user_scope, page_key, _browser_hash) when not is_binary(page_key) do
    raise ArgumentError, "page_key must be a string, got: #{inspect(page_key)}"
  end

  def new(_user_scope, _page_key, browser_hash) do
    raise ArgumentError, "browser_hash must be a string, got: #{inspect(browser_hash)}"
  end

  @spec any_browser(user_scope(), page_key()) :: t()
  def any_browser(user_scope, page_key) when is_binary(page_key) do
    %__MODULE__{user_scope: user_scope, page_key: page_key, browser_hash: :any}
  end
end
