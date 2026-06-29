import Config

env_config_path = Path.expand("#{config_env()}.exs", __DIR__)

if File.exists?(env_config_path) do
  import_config "#{config_env()}.exs"
end
