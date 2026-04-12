defmodule GridNest.AppJsPatcher do
  @moduledoc """
  Pure text transformations that teach a host Phoenix app's
  `assets/js/app.js` about GridNest.

  The patcher is deliberately string-based rather than AST-based: Phoenix's
  default `app.js` is a moving target across versions and any regex-light
  approach that recognises the common shapes is easier to reason about
  (and to leave alone when it already looks correct) than trying to parse
  arbitrary JavaScript.

  Three transformations happen in sequence:

    1. Ensure `import { GridNestBoard } from "../vendor/grid_nest.js"`
       appears near the other top-of-file imports.
    2. Ensure the `new LiveSocket(...)` options object contains a
       `hooks:` key with `GridNestBoard` inside it — either by adding a
       new key or by merging into an existing one.
    3. Skip both transformations when the file already references
       GridNestBoard, so the installer stays idempotent.
  """

  @import_line ~s(import { GridNestBoard } from "../vendor/grid_nest.js")

  @spec patch(String.t()) :: String.t()
  def patch(content) when is_binary(content) do
    content
    |> ensure_import()
    |> ensure_hook_registered()
  end

  defp ensure_import(content) do
    if String.contains?(content, @import_line) do
      content
    else
      insert_import_after_last_import(content)
    end
  end

  defp insert_import_after_last_import(content) do
    lines = String.split(content, "\n")

    last_import_index =
      lines
      |> Enum.with_index()
      |> Enum.filter(fn {line, _index} -> import_line?(line) end)
      |> Enum.map(fn {_line, index} -> index end)
      |> List.last()

    case last_import_index do
      nil ->
        @import_line <> "\n" <> content

      index ->
        {head, tail} = Enum.split(lines, index + 1)
        (head ++ [@import_line] ++ tail) |> Enum.join("\n")
    end
  end

  defp import_line?(line) do
    trimmed = String.trim_leading(line)
    String.starts_with?(trimmed, "import ")
  end

  defp ensure_hook_registered(content) do
    cond do
      hook_already_registered?(content) -> content
      has_hooks_key?(content) -> merge_into_existing_hooks(content)
      true -> add_hooks_key(content)
    end
  end

  defp hook_already_registered?(content) do
    String.contains?(content, "hooks:") and contains_hook_registration?(content)
  end

  defp contains_hook_registration?(content) do
    Regex.match?(~r/hooks:\s*\{[^}]*GridNestBoard[^}]*\}/, content)
  end

  defp has_hooks_key?(content) do
    Regex.match?(~r/hooks:\s*\{/, content)
  end

  defp merge_into_existing_hooks(content) do
    Regex.replace(~r/hooks:\s*\{([^}]*)\}/, content, fn _match, inner ->
      trimmed = String.trim(inner)

      cond do
        trimmed == "" -> "hooks: { GridNestBoard }"
        String.contains?(trimmed, "GridNestBoard") -> "hooks: {#{inner}}"
        true -> "hooks: { GridNestBoard, #{trimmed} }"
      end
    end)
  end

  defp add_hooks_key(content) do
    Regex.replace(
      ~r/new LiveSocket\(([^,]+),\s*([^,]+),\s*\{/,
      content,
      "new LiveSocket(\\1, \\2, {\n  hooks: { GridNestBoard },",
      global: false
    )
  end
end
