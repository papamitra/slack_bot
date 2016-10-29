# SlackBot

ElixirおよびPythonプラグインによる拡張可能なSlack Bot

## 実行

```bash
$ git clonse git@github.com:papamitra/slack_bot.git
$ cd slack_bot
$ mix deps.get
$ make -C deps/erlport/priv/python3
$ cat > config/secret.exs
use Mix.Config
config :slack_bot, token: :"<your slack bot api token>"
^C
$ mix compile
$ mix run --no-halt
```

## プラグイン

### Python

TODO

### Elixir

TODO
