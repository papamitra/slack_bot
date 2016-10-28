defmodule SlackBot do
  use GenServer

  require Logger

  def rtm_start do
    token = Application.get_env(:slack_bot, :token)
    opts = add_proxy_opt([])
    res = HTTPoison.get!("https://slack.com/api/rtm.start?token=#{token}", [], opts)

    team_state = Poison.decode!(res.body)

    %{"url" => url} = team_state

    GenServer.start_link(__MODULE__, [url, team_state])
  end

  def send_message(pid, msg, channel) do
    GenServer.cast(pid, {:send, msg, channel})
  end

  # callback function

  def init([url, team_state]) do
    plugins = Enum.map(Application.get_env(:slack_bot, :plugins), fn %{path: path, mod: mod} ->
      try do
        Code.append_path(path)
        {:module, mod}= Code.ensure_loaded(mod)

        {:ok, pid, cmds} = apply(mod, :plugin_init, [self, team_state])
        {mod, pid, cmds}
      rescue
        error ->
          Logger.warn "plugin loading failed: #{mod}, #{error}"
          nil
      end
    end) |> Enum.filter(fn x -> not is_nil(x) end)

    Enum.map(Application.get_env(:slack_bot, :python_plugins), fn %{path: path} ->
      {:ok, p} = :python.start([python_path: String.to_charlist(path)])
      :python.call(p, :pyecho, :plugin_init, [])
    end)

    {:ok, websocket} = WebsocketClient.start_link(self, url)

    {:ok, %{plugins: plugins, websocket: websocket, team_state: team_state, last_id: 0}}
  end

  def handle_info({:recv_text, text}, %{plugins: plugins, team_state: team_state} = state) do
    message = Poison.decode!(text)

    case valid_command?(message, team_state) do
      {:ok, {cmd, args, _channel}} ->
        Logger.debug "valid message: #{cmd} #{args}"
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

    {:noreply, state}
  end

  def handle_cast({:send, msg, channel}, %{websocket: websocket, last_id: last_id} = state) do
    payload = Poison.encode!(%{id: last_id + 1, type: "message", text: msg, channel: channel})
    websocket |> WebsocketClient.send({:text, payload})

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
    self_id = team_state |> Map.get("self") |> Map.get("id")

    with {:ok, "message"} <- Map.fetch(message, "type"),
         :error <- Map.fetch(message, "subtype"),
         :error <- Map.fetch(message, "editted"),
         :error <- Map.fetch(message, "pinned_to"),
         :error <- Map.fetch(message, "is_starred"),
         :error <- Map.fetch(message, "reactions"),
         {:ok, channel} <- Map.fetch(message, "channel"),
         {:ok, text} <- Map.fetch(message, "text"),
         %{"cmd" => cmd, "args" => args} <-
           Regex.named_captures(~r/<@#{self_id}> (?<cmd>\w+) +(?<args>.*)/, text),
      do:
         {:ok, {cmd, args, channel}}
  end
end
