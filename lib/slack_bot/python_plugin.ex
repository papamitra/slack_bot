defmodule SlackBot.Plugin.PythonPlugin do
  use GenServer

  require Logger

  def plugin_init(path, mod, class, parent, team_state) do
    Logger.debug "PythonPlugin plugin_init: #{path} #{mod} #{class}"

    GenServer.start_link(__MODULE__, [path, mod, class, parent, team_state])
  end

  def init([path, mod, class, parent, team_state]) do
    {:ok, python} = :python.start([python_path: ['python', String.to_charlist(path)], python: 'python3'])
    pyobj = python |> :python.call(mod, class, [])

    team_state_str = team_state |> Poison.encode!
    pyobj = python |> :python.call(mod, :"#{class}.plugin_init", [pyobj, parent, team_state_str])

    {:ok, %{parent: parent, python: python, pyobj: pyobj, mod: mod, class: class}}
  end

  def dispatch_command(pid, cmd, args, msg) do
    GenServer.cast(pid, {:command, cmd, args, msg})
  end

  def target_cmds(pid) do
    GenServer.call(pid, :target_cmds)
  end

  # callback function

  def handle_cast({:command, cmd, args, msg},
    %{python: python, pyobj: pyobj, mod: mod, class: class} = state) do

    msg_str = msg |> Poison.encode!
    pyobj = python |> :python.call(mod, :"#{class}.do_dispatch_command", [pyobj, cmd, args, msg_str])
    {:noreply, %{state | pyobj: pyobj}}
  end

  def handle_call(:target_cmds, _from, %{python: python, pyobj: pyobj, mod: mod, class: class} = state) do
    cmds = python |> :python.call(mod, :"#{class}.target_cmds", [pyobj])
    {:reply, {:ok, cmds}, state}
  end

end
