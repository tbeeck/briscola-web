defmodule Briscolino.ShortIdTest do
  use ExUnit.Case

  test "generate short id" do
    assert String.length(Briscolino.ShortId.new()) == 6
  end

  test "ids are binary" do
    assert is_binary(Briscolino.ShortId.new())
  end

  test "ids are unique" do
    ids = Enum.map(1..10, fn _ -> Briscolino.ShortId.new() end)
    assert Enum.uniq(ids) == ids
  end
end
