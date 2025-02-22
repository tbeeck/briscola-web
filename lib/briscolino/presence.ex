defmodule Briscolino.Presence do
  use Phoenix.Presence,
    otp_app: :briscolino,
    pubsub_server: Briscolino.PubSub
end
