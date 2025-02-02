defmodule Briscolino.GameServer do
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], [])
  end
end
