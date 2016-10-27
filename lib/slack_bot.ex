defmodule SlackBot do
  use WebsocketClient

  require Logger

  def rtm_start do
    token = Application.get_env(:slack_bot, :token)
    opts = add_proxy_opt([])
    res = HTTPoison.get!("https://slack.com/api/rtm.start?token=#{token}", [], opts)

    team_state = Poison.Parser.parse(res.body, keys: :atoms!)

    %{"url" => url} = team_state

    WebsocketClient.start_link(__MODULE__, url, team_state)
  end

  def send_message(pid, msg, channel) do
    GenServer.cast(pid, {:send, msg, channel})
  end

  # callback function

  def init(team_state) do
    plugins = Enum.map(Application.get_env(:slack_bot, :plugins), fn %{path: path, mod: mod} ->
      try do
        Code.append_path(path)
        {:module, mod}= Code.ensure_loaded(mod)

        {:ok, pid, cmds} = apply(mod, :plugin_init, [self])
        {mod, pid, cmds}
      rescue
        error ->
          Logger.warn "plugin loading failed: #{mod}, #{error}"
          nil
      end
    end) |> Enum.filter(fn x -> not is_nil(x) end)

    {:ok, %{plugins: plugins, team_state: team_state, last_id: 0}}
  end

  def handle_text(text, %{plugins: plugins, team_state: team_state} = state) do
    message = Poison.Parser.parse!(text, keys: :atoms!)

    case valid_command?(message, team_state) do
      {:ok, {cmd, args, _channel}} ->
        Enum.each(plugins, fn({mod, pid, cmds}) ->
          if Enum.any?(cmds, fn c -> Atom.to_string(c) == cmd end) do
            try do
              apply(mod, :dispatch_command, [pid, String.to_atom(cmd), args, message])
            rescue
              error ->
                Logger.warn "#{mod}.handle_text failed: #{error}"
            end
          end
        end)
      _ ->
        :noop
    end

    {:ok, state}
  end

  def handle_cast({:send, msg, channel}, _from, %{last_id: last_id} = state) do
    WebsocketClient.send(self, Poison.encode!(%{id: last_id + 1, type: "message", text: msg, channel: channel}))

    {:noreply, %{state | last_id: last_id + 1}}
  end

  # private

  defp add_proxy_opt(acc) do
    https_proxy = System.get_env("https_proxy")
    case  (https_proxy || "") |> URI.parse do
      %URI{host: proxy_host} when not is_nil(proxy_host) ->
        Logger.info "use proxy: #{https_proxy}"
        [{:proxy, https_proxy} | acc]
      _ ->
        acc
    end
  end

  defp valid_command?(message, team_state) do
    self_id = team_state.self.id

    with {:ok, "message"} <- Map.fetch(message, :type),
         :error <- Map.fetch(message, :subtype),
         :error <- Map.fetch(message, :editted),
         :error <- Map.fetch(message, :pinned_to),
         :error <- Map.fetch(message, :is_starred),
         :error <- Map.fetch(message, :reactions),
         {:ok, channel} <- Map.fetch(message, :channel),
         {:ok, text} <- Map.fetch(message, :text),
         %{"cmd" => cmd, "args" => args} <- Regex.named_captures(~r/<@#{self_id}> (?<cmd>\w.+)(?<args>.*)/, text),
      do:
         {:ok, {cmd, args, channel}}
  end
end
