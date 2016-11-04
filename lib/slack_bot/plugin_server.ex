defmodule SlackBot.PluginServer do
  use GenServer
  import Supervisor.Spec

  require Logger

  def start_link(sup, team_state) do
    GenServer.start_link(__MODULE__, [sup, team_state], name: __MODULE__)
  end

  def init([sup, team_state]) do
    Enum.each(Application.get_env(:slack_bot, :plugins) || [],
      fn %{path: path, mod: mod} ->
        send(self, {:create_plugin, path, mod, team_state})
      end)

    Enum.each(Application.get_env(:slack_bot, :python_plugins) || [],
      fn %{path: path, mod: mod, class: class} ->
        send(self, {:create_python_plugin, path, mod, class, team_state})
      end)

    {:ok, %{sup: sup, plugins: %{}}}
  end

  # callback function

  def handle_info({:create_plugin, path, mod, team_state}, %{sup: sup} = state) do
    Logger.debug "create plugin: #{mod}"
    worker = worker(SlackBot.Plugin, [path, mod, team_state], [restart: :temporary])
    Supervisor.start_child(sup, worker)
    {:noreply, state}
  end

  def handle_info({:create_python_plugin, path, mod, class, team_state}, %{sup: sup} = state) do
    Logger.debug "create python plugin: #{mod}.#{class}"
    worker = worker(SlackBot.Plugin.PythonPlugin, [path, mod, class, team_state], [restart: :temporary])
    Supervisor.start_child(sup, worker)
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
