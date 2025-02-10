defmodule BriscolinoWeb.Router do
  use BriscolinoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BriscolinoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BriscolinoWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/game", BriscolinoWeb do
    pipe_through :browser

    live "/:id", LiveGame.Board
  end

  if Application.compile_env(:briscolino, :dev_routes) do
    scope "/debug", BriscolinoWeb do
      pipe_through :browser

      get "/", DebugController, :devgame

      get "/viewgame/:id", DebugController, :view_game
      post "/newgame", DebugController, :create_game
      post "/viewgame/:id/play/:card", DebugController, :play_card
      delete "/endgame/:id", DebugController, :end_game

      live "/livegame/:id", DebugGameLive
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", BriscolinoWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:briscolino, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BriscolinoWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
