defmodule SlackBot.PythonPluginsSupervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    worker_opts = [restart: :temporary]

    children = [
      worker(SlackBot.Plugin.PythonPlugin, [], worker_opts)
    ]

    opts = [
      strategy: :simple_one_for_one,
      max_restarts: 0
    ]

    supervise(children, opts)
  end

end
