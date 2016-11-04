defmodule SlackBot.Plugin do
  use GenServer

  @doc """
  Called when the bot load this plugin.
  """
  @callback plugin_init(pid, any) :: {:ok, pid, [atom]}

  @doc """
  Called when the bot dispatch command.
  """
  @callback dispatch_command(atom, String.t, any, any) :: :ok

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour SlackBot.Plugin

      @doc false
      def plugin_init(_team_state) do
        {:ok, nil, []}
      end

      def dispatch_command(_pid, _cmd, _args, _msg) do
        :ok
      end

      defoverridable [plugin_init: 1, dispatch_command: 4]
    end
  end

  def start_link(path, mod, team_state) do
    GenServer.start_link(__MODULE__, [path, mod, team_state])
  end

  # callback funtion

  def init([path, mod, team_state]) do
    send(self, {:plugin_init, path, mod, team_state})
    {:ok, nil}
  end

  def handle_info({:command, cmd, args, msg}, %{mod: mod, pid: pid, cmds: cmds} = state) do
    if Enum.any?(cmds, fn c -> Atom.to_string(c) == cmd end) do
      apply(mod, :dispatch_command, [pid, String.to_atom(cmd), args, msg])
    end

    {:noreply, state}
  end

  def handle_info({:plugin_init, path, mod, team_state}, _state) do
    Code.append_path(path)
    {:module, mod}= Code.ensure_loaded(mod)

    {:ok, pid, cmds} = apply(mod, :plugin_init, [team_state])

    send(SlackBot.PluginServer, {:register_plugin, self, cmds})

    {:noreply, %{mod: mod, pid: pid, cmds: cmds}}
  end

end
