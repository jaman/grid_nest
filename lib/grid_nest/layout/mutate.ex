defmodule GridNest.Layout.Mutate do
  @moduledoc """
  Pure collision-aware mutations on a `GridNest.Layout`.

  The three entry points are `move/3`, `resize/3`, and `compact/1`.
  Each returns a valid (non-overlapping, unique-id) layout, pushing
  colliding siblings downward when needed and — for `compact/1` —
  pulling tiles upward into any gap that the previous step opened.

  The resolution order for pushes is deterministic: for any collision,
  the *non-primary* tile (the one that wasn't directly acted on) moves,
  never the one the user is dragging. Cascades are resolved by
  iterating until a stable layout is reached.
  """

  alias GridNest.Layout
  alias GridNest.Layout.Item

  @type coord :: %{required(:x) => integer(), required(:y) => integer()}
  @type size :: %{required(:w) => integer(), required(:h) => integer()}

  @type mutate_error ::
          {:not_found, String.t()}
          | {:invalid, :x | :y | :w | :h}
          | :not_movable
          | :not_resizable
          | {:blocked_by, String.t()}

  @spec move(Layout.t(), String.t(), coord()) ::
          {:ok, Layout.t()} | {:error, mutate_error()}
  def move(layout, id, %{x: x, y: y}) when is_list(layout) and is_binary(id) do
    with :ok <- validate_non_negative(x, :x),
         :ok <- validate_non_negative(y, :y),
         {:ok, target} <- fetch(layout, id),
         :ok <- ensure_movable(target) do
      updated = %Item{target | x: x, y: y}
      others = Enum.reject(layout, &(&1.id == id))
      resolve([updated | others], updated)
    end
  end

  @spec resize(Layout.t(), String.t(), size()) ::
          {:ok, Layout.t()} | {:error, mutate_error()}
  def resize(layout, id, %{w: w, h: h}) when is_list(layout) and is_binary(id) do
    with :ok <- validate_positive(w, :w),
         :ok <- validate_positive(h, :h),
         {:ok, target} <- fetch(layout, id),
         :ok <- ensure_resizable(target) do
      updated = %Item{target | w: w, h: h}
      others = Enum.reject(layout, &(&1.id == id))
      resolve([updated | others], updated)
    end
  end

  @spec compact(Layout.t()) :: Layout.t()
  def compact(layout) when is_list(layout) do
    layout
    |> Enum.sort_by(fn %Item{y: y, x: x} -> {y, x} end)
    |> Enum.reduce([], fn item, placed ->
      placed ++ [pull_up(item, placed)]
    end)
  end

  defp fetch(layout, id) do
    case Enum.find(layout, &(&1.id == id)) do
      nil -> {:error, {:not_found, id}}
      %Item{} = item -> {:ok, item}
    end
  end

  defp validate_non_negative(value, _field) when is_integer(value) and value >= 0, do: :ok
  defp validate_non_negative(_value, field), do: {:error, {:invalid, field}}

  defp validate_positive(value, _field) when is_integer(value) and value > 0, do: :ok
  defp validate_positive(_value, field), do: {:error, {:invalid, field}}

  defp ensure_movable(%Item{movable: true}), do: :ok
  defp ensure_movable(%Item{movable: false}), do: {:error, :not_movable}

  defp ensure_resizable(%Item{resizable: true}), do: :ok
  defp ensure_resizable(%Item{resizable: false}), do: {:error, :not_resizable}

  defp resolve(layout, %Item{} = primary) do
    case first_collision(layout, primary, [primary.id]) do
      nil -> {:ok, order_by_original(layout)}
      other -> cascade_push(layout, primary, other, [primary.id])
    end
  end

  defp cascade_push(_layout, _pusher, %Item{movable: false, id: id}, _locked_ids) do
    {:error, {:blocked_by, id}}
  end

  defp cascade_push(layout, %Item{} = pusher, %Item{} = other, locked_ids) do
    pushed = %Item{other | y: pusher.y + pusher.h}

    layout
    |> replace_item(other.id, pushed)
    |> resolve_cascades(locked_ids, pushed)
  end

  defp resolve_cascades(layout, locked_ids, %Item{} = last_moved) do
    locked = Enum.uniq([last_moved.id | locked_ids])

    case first_collision(layout, last_moved, locked) do
      %Item{} = direct -> cascade_push(layout, last_moved, direct, locked)
      nil -> resolve_indirect(layout, locked)
    end
  end

  defp resolve_indirect(layout, locked) do
    case next_primary_collision(layout, locked) do
      nil -> {:ok, order_by_original(layout)}
      {primary, other} -> cascade_push(layout, primary, other, locked)
    end
  end

  defp first_collision(layout, %Item{} = subject, excluded_ids) do
    Enum.find(layout, fn other ->
      other.id not in excluded_ids and Item.collides?(subject, other)
    end)
  end

  defp next_primary_collision(layout, locked) do
    layout
    |> Enum.filter(&(&1.id in locked))
    |> Enum.find_value(fn primary ->
      case first_collision(layout, primary, locked) do
        nil -> nil
        other -> {primary, other}
      end
    end)
  end

  defp replace_item(layout, id, replacement) do
    Enum.map(layout, fn item -> if item.id == id, do: replacement, else: item end)
  end

  defp order_by_original(layout) do
    Enum.sort_by(layout, fn %Item{id: id} -> id end)
  end

  defp pull_up(%Item{} = item, placed) do
    Enum.reduce_while(0..item.y, item, fn candidate_y, _acc ->
      candidate = %Item{item | y: candidate_y}

      if Enum.any?(placed, &Item.collides?(candidate, &1)) do
        {:cont, item}
      else
        {:halt, candidate}
      end
    end)
  end
end
