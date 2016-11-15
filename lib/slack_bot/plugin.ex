defmodule SlackBot.Plugin do
  use GenServer

  require Logger

  @doc """
  Called when the bot load this plugin.
  """
  @callback plugin_init(any) :: {:ok, pid, [atom]}

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

  def start_link(path, mod, app, team_state) do
    GenServer.start_link(__MODULE__, [path, mod, app, team_state])
  end

  # callback funtion

  def init([path, mod, app, team_state]) do
    send(self, {:plugin_init, path, mod, app, team_state})
    {:ok, nil}
  end

  def handle_info({:command, cmd, args, msg}, %{mod: mod, pid: pid, cmds: cmds} = state) do
    if Enum.any?(cmds, fn c -> Atom.to_string(c) == cmd end) do
      apply(mod, :dispatch_command, [pid, String.to_atom(cmd), args, msg])
    end

    {:noreply, state}
  end

  def handle_info({:plugin_init, path, mod, app, team_state}, _state) do

    Code.append_path(path <> "/_build/#{Mix.env}/lib/#{app}/ebin") # FIXME: code path

    :ok = Application.load(app)

    case Code.ensure_loaded(mod) do
      {:module, mod} ->
        Logger.debug "module load succeeded: #{mod}"
      _ ->
        Logger.warn "module load failed: #{mod}"
        exit(:load_failed)
    end

    {:ok, pid, cmds} = apply(mod, :plugin_init, [team_state])

    send(SlackBot.PluginServer, {:register_plugin, self, cmds})

    {:noreply, %{}}
  end

end
