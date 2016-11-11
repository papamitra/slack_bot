defmodule SlackBot.PluginSupervisor do
  use Supervisor

  def start_link(team_state) do
    Supervisor.start_link(__MODULE__, [team_state], name: __MODULE__)
  end

  def init(team_state) do
    children = [
      worker(SlackBot.PluginServer, [team_state])
    ]

    opts = [
      strategy: :one_for_all,
      max_restarts: 0
    ]

    supervise(children, opts)
  end

end
