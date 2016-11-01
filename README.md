# SlackBot

ElixirおよびPythonプラグインによる拡張可能なSlack Bot

## 実行

```bash
$ git clonse https://github.com/papamitra/slack_bot.git
$ cd slack_bot
$ cat > config/secret.exs
use Mix.Config
config :slack_bot, token: :"<your slack bot api token>"
^C
$ mix deps.get
$ make -C deps/erlport/priv/python3

$ cd plugins/echo
$ mix deps.get
$ mix compile
$ cd ../../

$ mix compile
$ mix run --no-halt
```

## プラグイン

### Python

TODO

### Elixir

TODO
