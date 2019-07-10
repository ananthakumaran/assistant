import Config

config :assistant,
  poll_interval: String.to_integer(System.get_env("GITLAB_POLL_INTERVAL_SECONDS", "60")),
  private_token: System.fetch_env!("GITLAB_TOKEN"),
  gitlab_host: System.fetch_env!("GITLAB_HOST"),
  projects: String.split(System.fetch_env!("GITLAB_PROJECTS"), ",", trim: true),
  proxy: System.get_env("HTTP_PROXY")
