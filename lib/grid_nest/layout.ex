defmodule GridNest.Layout do
  @moduledoc """
  A layout is an ordered list of `GridNest.Layout.Item` structs that must
  all have unique ids and must not overlap.
  """

  alias GridNest.Layout.Item

  @type t :: [Item.t()]

  @type new_error ::
          {:duplicate_id, String.t()}
          | {:collision, String.t(), String.t()}
          | {:item, map(), term()}

  @spec new([Item.t() | map()]) :: {:ok, t()} | {:error, new_error()}
  def new(items) when is_list(items) do
    with {:ok, built} <- build_items(items),
         :ok <- check_unique(built),
         :ok <- check_collisions(built) do
      {:ok, built}
    end
  end

  @spec new!([Item.t() | map()]) :: t()
  def new!(items) do
    case new(items) do
      {:ok, layout} -> layout
      {:error, reason} -> raise ArgumentError, "invalid layout: #{inspect(reason)}"
    end
  end

  @doc """
  Serializes a layout to a plain list of maps for the wire format.

  Only the positional fields (`id`, `x`, `y`, `w`, `h`) are included —
  the `movable`/`resizable` flags are *structural* properties defined by
  the host app's `default_layout` and are reapplied from the bootstrap
  layout on hydrate. They deliberately do not round-trip through the
  client so that a stale or tampered localStorage entry can never flip a
  locked tile back to interactive.
  """
  @spec to_wire(t()) :: [map()]
  def to_wire(layout) when is_list(layout) do
    Enum.map(layout, fn %Item{id: id, x: x, y: y, w: w, h: h} ->
      %{id: id, x: x, y: y, w: w, h: h}
    end)
  end

  defp build_items(items) do
    Enum.reduce_while(items, {:ok, []}, fn raw, {:ok, acc} ->
      case to_item(raw) do
        {:ok, item} -> {:cont, {:ok, [item | acc]}}
        {:error, reason} -> {:halt, {:error, {:item, raw, reason}}}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
      other -> other
    end
  end

  defp to_item(%Item{} = item), do: {:ok, item}
  defp to_item(attrs) when is_map(attrs), do: Item.new(attrs)

  defp check_unique(items) do
    items
    |> Enum.reduce_while(MapSet.new(), fn %Item{id: id}, seen ->
      if MapSet.member?(seen, id) do
        {:halt, {:duplicate_id, id}}
      else
        {:cont, MapSet.put(seen, id)}
      end
    end)
    |> case do
      %MapSet{} -> :ok
      {:duplicate_id, id} -> {:error, {:duplicate_id, id}}
    end
  end

  defp check_collisions(items) do
    items
    |> pairs()
    |> Enum.find_value(:ok, fn {a, b} ->
      if Item.collides?(a, b), do: {:error, {:collision, a.id, b.id}}
    end)
  end

  defp pairs([]), do: []
  defp pairs([head | tail]), do: Enum.map(tail, &{head, &1}) ++ pairs(tail)
end
