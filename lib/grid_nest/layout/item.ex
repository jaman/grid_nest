defmodule GridNest.Layout.Item do
  @moduledoc """
  A single positioned tile on a `GridNest` board.

  Coordinates are expressed in grid cells (not pixels): `x`/`y` are the
  zero-based origin of the tile and `w`/`h` are spans. Width and height
  are always positive.

  Two optional boolean flags, both defaulting to `true`, control user
  interaction:

    * `:movable` — when `false`, the tile cannot be dragged by the user,
      and collision cascades will not push it (it acts like a wall).
    * `:resizable` — when `false`, the tile cannot be resized by the
      user (its resize handle is not rendered).
  """

  @enforce_keys [:id, :x, :y, :w, :h]
  defstruct [:id, :x, :y, :w, :h, movable: true, resizable: true]

  @type t :: %__MODULE__{
          id: String.t(),
          x: non_neg_integer(),
          y: non_neg_integer(),
          w: pos_integer(),
          h: pos_integer(),
          movable: boolean(),
          resizable: boolean()
        }

  @type input :: %{
          optional(:id) => String.t(),
          optional(:x) => integer(),
          optional(:y) => integer(),
          optional(:w) => integer(),
          optional(:h) => integer(),
          optional(:movable) => boolean(),
          optional(:resizable) => boolean()
        }

  @spec new(map()) :: {:ok, t()} | {:error, {:missing | :invalid, atom()}}
  def new(attrs) when is_map(attrs) do
    with {:ok, id} <- fetch_id(attrs),
         {:ok, x} <- fetch_coord(attrs, :x),
         {:ok, y} <- fetch_coord(attrs, :y),
         {:ok, w} <- fetch_span(attrs, :w),
         {:ok, h} <- fetch_span(attrs, :h),
         {:ok, movable} <- fetch_flag(attrs, :movable),
         {:ok, resizable} <- fetch_flag(attrs, :resizable) do
      {:ok,
       %__MODULE__{
         id: id,
         x: x,
         y: y,
         w: w,
         h: h,
         movable: movable,
         resizable: resizable
       }}
    end
  end

  @spec new!(map()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, item} -> item
      {:error, reason} -> raise ArgumentError, "invalid item: #{inspect(reason)}"
    end
  end

  @spec collides?(t(), t()) :: boolean()
  def collides?(%__MODULE__{id: id}, %__MODULE__{id: id}), do: false

  def collides?(%__MODULE__{} = a, %__MODULE__{} = b) do
    a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
  end

  defp fetch_id(attrs) do
    case pick(attrs, :id) do
      value when is_binary(value) and value != "" -> {:ok, value}
      nil -> {:error, {:missing, :id}}
      _ -> {:error, {:invalid, :id}}
    end
  end

  defp fetch_coord(attrs, field) do
    case pick(attrs, field) do
      nil -> {:error, {:missing, field}}
      value when is_integer(value) and value >= 0 -> {:ok, value}
      _ -> {:error, {:invalid, field}}
    end
  end

  defp fetch_span(attrs, field) do
    case pick(attrs, field) do
      nil -> {:error, {:missing, field}}
      value when is_integer(value) and value > 0 -> {:ok, value}
      _ -> {:error, {:invalid, field}}
    end
  end

  defp fetch_flag(attrs, field) do
    case pick(attrs, field) do
      nil -> {:ok, true}
      value when is_boolean(value) -> {:ok, value}
      _ -> {:error, {:invalid, field}}
    end
  end

  defp pick(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> value
      :error -> Map.get(attrs, Atom.to_string(key))
    end
  end
end
