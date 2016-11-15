defmodule SlackBot.PluginServer do
  use GenServer
  import Supervisor.Spec

  require Logger

  def start_link(team_state) do
    GenServer.start_link(__MODULE__, [team_state], name: __MODULE__)
  end

  def init([team_state]) do
    # TODO: assign to PluginSupervisor
    {:ok, elixir_plugins_sup} = SlackBot.ElixirPluginsSupervisor.start_link()
    {:ok, python_plugins_sup} = SlackBot.PythonPluginsSupervisor.start_link()

    Enum.each(Application.get_env(:slack_bot, :plugins) || [],
      fn %{path: path, mod: mod, app: app} ->
        send(self, {:create_plugin, Path.expand(path), mod, app, team_state})
      end)

    Enum.each(Application.get_env(:slack_bot, :python_plugins) || [],
      fn %{path: path, mod: mod, class: class} ->
        send(self, {:create_python_plugin, Path.expand(path), mod, class, team_state})
      end)

    {:ok, %{elixir_plugins_sup: elixir_plugins_sup,
            python_plugins_sup: python_plugins_sup,
            plugins: %{}}}
  end

  # callback function

  def handle_info({:create_plugin, path, mod, app, team_state}, %{elixir_plugins_sup: sup} = state) do
    Logger.debug "create plugin: #{mod}"
    Supervisor.start_child(sup, [path, mod, app, team_state])
    {:noreply, state}
  end

  def handle_info({:create_python_plugin, path, mod, class, team_state}, %{python_plugins_sup: sup} = state) do
    Logger.debug "create python plugin: #{mod}.#{class}"
    ret = Supervisor.start_child(sup, [path, mod, class, team_state])
    Logger.debug "create_python_plugin: #{inspect ret}"
    {:noreply, state}
  end

  def handle_info({:recv_command, cmd, args, msg}, %{plugins: plugins} = state) do
    Enum.each(plugins, fn {pid, %{cmds: cmds} } ->
      if Enum.any?(cmds, fn c -> Atom.to_string(c) == cmd end) do
        send(pid, {:command, cmd, args, msg})
      end
    end)

    {:noreply, state}
  end

  def handle_info({:DOWN, ref, _, pid, reason}, %{plugins: plugins} = state) do
    Logger.warn "plugin downed: #{Map.get(plugins, pid)}, #{inspect reason}"
    Process.demonitor(ref)
    {:noreply, %{state | plugins: Map.delete(plugins, pid)}}
  end

  def handle_info({:EXIT, pid, reason}, %{plugins: plugins} = state) do
    Logger.warn "plugin exited: #{Map.get(plugins, pid)}, #{inspect reason}"
    # TODO: 
    {:noreply, state}
  end

  def handle_info({:register_plugin, pid, cmds}, %{plugins: plugins} = state) do
    ref = Process.monitor(pid)
    {:noreply, %{state | plugins: Map.put(plugins, pid, %{ref: ref, cmds: cmds}) }}
  end

  def handle_info(event, state) do
    Logger.warn "recv unknown event: #{event}"
    {:noreply, state}
  end

end
