defmodule SlackBot.PluginsSupervisor do
  use Supervisor

  def start_link(team_state) do
    Supervisor.start_link(__MODULE__, [team_state], name: __MODULE__)
  end

  def init(team_state) do
    children = [
      worker(SlackBot.PluginServer, [self, team_state])
    ]

    opts = [
      strategy: :one_for_one
    ]

    supervise(children, opts)
  end

end
