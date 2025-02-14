defmodule BriscolinoWeb.UserSessions do
  alias Briscolino.ShortId
  import Plug.Conn

  @doc """
  Put a unique ID in the user's session.
  This is used to determine when it's their turn to play
  in any given game.
  """
  def assign_session_id(conn, _opts) do
    if get_session(conn, :session_id) do
      conn
    else
      id = ShortId.new() <> ShortId.new()
      put_session(conn, :session_id, id)
    end
  end
end
