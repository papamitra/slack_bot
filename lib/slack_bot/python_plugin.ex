defmodule SlackBot.Plugin.PythonPlugin do
  use GenServer

  require Logger

  def start_link(path, mod, class, team_state) do
    Logger.debug "PythonPlugin plugin_init: #{path} #{mod} #{class}"

    GenServer.start_link(__MODULE__, [path, mod, class, team_state])
  end

  def init([path, mod, class, team_state]) do
    send(self, {:plugin_init, path, mod, class, team_state})
    {:ok, nil}
  end

  # callback function

  def handle_info({:command, cmd, args, msg},
    %{python: python, pyobj: pyobj, mod: mod, class: class, cmds: cmds} = state) do

    case Enum.any?(cmds, fn c -> Atom.to_string(c) == cmd end) do
      true ->
        msg_str = msg |> Poison.encode!
        pyobj = python |> :python.call(mod, :"#{class}.do_dispatch_command", [pyobj, cmd, args, msg_str])
        {:noreply, %{state | pyobj: pyobj}}
      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:plugin_init, path, mod, class, team_state}, _state) do
    {:ok, python} = :python.start([python_path: ['python', String.to_charlist(path)], python: 'python3'])
    pyobj = python |> :python.call(mod, class, [])

    team_state_str = team_state |> Poison.encode!
    pyobj = python |> :python.call(mod, :"#{class}.plugin_init", [pyobj, team_state_str])

    cmds = python |> :python.call(mod, :"#{class}.target_cmds", [pyobj])

    send(SlackBot.PluginServer, {:register_plugin, self, cmds})

    {:noreply, %{python: python, pyobj: pyobj, mod: mod, class: class, cmds: cmds, team_state: team_state}}
  end

end
