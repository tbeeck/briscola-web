import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :briscolino, BriscolinoWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "GVLsv0M8ez48MPr8SHgMwrlGBWr+H0ClBZ2+8g4zOG2Sfh3mBe71dqyTL0UgvAcq",
  server: false

# In test we don't send emails
config :briscolino, Briscolino.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
