defmodule GridNestTest do
  use ExUnit.Case, async: true

  test "the top-level module exists as a documentation anchor" do
    assert Code.ensure_loaded?(GridNest)
  end
end
