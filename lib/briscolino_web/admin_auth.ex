defmodule BriscolinoWeb.AdminAuth do
  @configured_creds Application.compile_env(:briscolino, :admin_auth)

  def admin_auth(conn, _opts) do
    # If we accidentally don't configure these variables,
    # username/password will be nil in non-development
    # environments (assuming no username/pass was configured
    # in the config file for the given environment)
    # When nothing is configured, admin routes are forbidden.
    creds =
      case @configured_creds do
        nil -> []
        val -> val
      end

    username =
      case System.get_env("ADMIN_USERNAME") do
        nil -> Keyword.get(creds, :username, nil)
        val -> val
      end

    password =
      case System.get_env("ADMIN_PASSWORD") do
        nil -> Keyword.get(creds, :password, nil)
        val -> val
      end

    creds = [username: username, password: password]

    if username != nil and password != nil do
      Plug.BasicAuth.basic_auth(conn, creds)
    else
      conn
      |> Plug.Conn.send_resp(:forbidden, "Forbidden")
    end
  end
end
