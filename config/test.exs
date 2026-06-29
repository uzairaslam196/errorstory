import Config

config :error_story, :req_options, plug: {Req.Test, ErrorStory.Request}
