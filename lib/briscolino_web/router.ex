defmodule BriscolinoWeb.Router do
  use BriscolinoWeb, :router

  import BriscolinoWeb.AdminAuth
  import BriscolinoWeb.UserSessions
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :assign_session_id
    plug :assign_username
    plug :assign_device
    plug :fetch_live_flash
    plug :put_root_layout, html: {BriscolinoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # User-facing routes
  scope "/", BriscolinoWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/about", PageController, :about
  end

  scope "/game", BriscolinoWeb do
    pipe_through :browser

    post "/new", PageController, :new_sp_game
    live "/:id", LiveGame.Board
  end

  scope "/lobby", BriscolinoWeb do
    pipe_through :browser

    post "/new", PageController, :new_lobby
    live "/:id", LiveGame.Lobby
  end

  # Admin / msc routes
  pipeline :admin do
    plug :admin_auth
  end

  scope "/dev", BriscolinoWeb do
    pipe_through [:browser, :admin]

    get "/", DebugController, :devgame

    # Debug game management stuff
    get "/viewgame/:id", DebugController, :view_game
    post "/newgame", DebugController, :create_game
    post "/newgame/sp", DebugController, :create_game_sp
    post "/viewgame/:id/play/:card", DebugController, :play_card
    delete "/endgame/:id", DebugController, :end_game
    live "/livegame/:id", DebugGameLive

    live_dashboard "/dashboard", metrics: BriscolinoWeb.Telemetry
  end
end
