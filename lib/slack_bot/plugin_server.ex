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

  def handle_info({:create_plugin, path, mod, team_state}, %{sup: sup, plugins: plugins} = state) do
    Logger.debug "create plugin: #{mod}"
    worker = worker(SlackBot.Plugin, [path, mod, team_state], [restart: :temporary])
    case Supervisor.start_child(sup, worker) do
      {:ok, pid} ->
        Process.monitor(pid)
        {:noreply, %{state| plugins: Map.put(plugins, pid, mod) }}
      error ->
        Logger.warn "plugin load failed: #{mod}, #{error}"
        {:noreply, state}
    end
  end

  def handle_info({:create_python_plugin, path, mod, class, team_state}, %{sup: sup, plugins: plugins} = state) do
    Logger.debug "create python plugin: #{mod}.#{class}"
    worker = worker(SlackBot.Plugin.PythonPlugin, [path, mod, class, team_state], [restart: :temporary])
    case Supervisor.start_child(sup, worker) do
      {:ok, pid} ->
        Process.monitor(pid)
        {:noreply, %{state| plugins: Map.put(plugins, pid, mod) }}
      error ->
        Logger.warn "python plugin load failed: #{mod}.#{class}, #{error}"
        {:noreply, state}
    end
  end

  def handle_info({:recv_command, cmd, args, msg}, %{plugins: plugins} = state) do
    Enum.each(plugins, fn {pid, _mod} ->
      send(pid, {:command, cmd, args, msg})
    end)

    {:noreply, state}
  end

end
