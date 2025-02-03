defmodule Briscolino.ShortId do
  @spec base62_chars() :: tuple()
  def base62_chars,
    do:
      "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
      |> String.split("")
      |> List.to_tuple()

  @spec new() :: binary()
  def new() do
    chars = base62_chars()
    # 6 characters long
    Enum.map(1..6, fn _ ->
      elem(chars, :rand.uniform(62) - 1)
    end)
    |> Enum.join()
  end
end
