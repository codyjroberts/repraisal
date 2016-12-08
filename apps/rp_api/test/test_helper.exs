# Load env variables
"source #{Application.get_env(:comment_pipeline, :env)}"
|> String.to_char_list()
|> :os.cmd

ExUnit.start()
