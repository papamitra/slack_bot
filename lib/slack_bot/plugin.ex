defmodule SlackBot.Plugin do

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
      def plugin_init(_parent, _team_state) do
        {:ok, nil, []}
      end

      def dispatch_command(_cmd, _args, _msg) do
        :ok
      end

      defoverridable [plugin_init: 2, dispatch_command: 3]
    end
  end

end
