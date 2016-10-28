defmodule SlackBot.Plugin.Echo do
  use GenServer
  use SlackBot.Plugin

  require Logger

  def plugin_init(parent, team_state) do
    Logger.debug "Echo plugin init"

    {:ok, pid} = GenServer.start_link(__MODULE__, [parent, team_state])
    {:ok, pid, [:echo]}
  end

  # callback function

  def init([parent, team_state]) do
    {:ok, %{parent: parent, team_state: team_state}}
  end

  def dispatch_command(pid, :echo, args, msg) do
    GenServer.cast(pid, {:send, args, msg})
  end

  def handle_cast({:send, args, msg}, %{parent: parent} = state) do
    SlackBot.send_message(parent, args, Map.get(msg, "channel"))
    {:noreply, state}
  end

end
