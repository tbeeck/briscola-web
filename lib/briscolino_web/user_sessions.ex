defmodule BriscolinoWeb.UserSessions do
  alias Briscolino.ShortId
  import Plug.Conn

  @type username_config_t() :: %{
          nouns: %{male: [String.t()], female: [String.t()]},
          adjectives: [%{male: String.t(), female: String.t()}]
        }

  @username_config_file "priv/usernames.json"
  @username_config @username_config_file |> File.read!() |> Jason.decode!()
  @external_resource @username_config_file

  @doc """
  Put a unique ID in the user's session.
  This is used to determine when it's their turn to play
  in any given game.
  """
  def assign_session_id(conn, _opts) do
    if get_session(conn, :session_id) do
      conn
    else
      put_session(conn, :session_id, random_player_id())
    end
  end

  def assign_username(conn, _opts) do
    if get_session(conn, :username) do
      conn
    else
      put_session(conn, :username, random_username())
    end
  end

  def random_player_id() do
    ShortId.new() <> ShortId.new()
  end

  def random_username() do
    gender =
      Enum.random(["male", "female"])

    noun =
      Enum.random(@username_config["nouns"][gender])

    adjective =
      Enum.random(@username_config["adjectives"])[gender]

    noun <> adjective
  end
end
