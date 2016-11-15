defmodule SlackBot do
  use GenServer

  @behaviour SlackBot.Behaviour

  require Logger

  def start(_type, _args) do
    {:ok, res} = SlackBot.WebAPI.get(:"rtm.start")
    team_state = Poison.decode!(res.body)

    %{"url" => url} = team_state

    GenServer.start_link(__MODULE__, [url, team_state], name: __MODULE__)
  end

  def send_message(msg, channel) do
    GenServer.cast(__MODULE__, {:send, msg, channel})
  end

  def send_direct_message(msg, user) do
    GenServer.cast(__MODULE__, {:send_dm, msg, user})
  end

  # callback function

  def init([url, team_state]) do
    SlackBot.PluginSupervisor.start_link(team_state)
    dm_channels = :ets.new(:dm_channels, [:set, :private])
    {:ok, websocket} = WebsocketClient.start_link(self, url)
    {:ok, %{websocket: websocket, team_state: team_state, last_id: 0, dm_channels: dm_channels}}
  end

  def handle_info({:recv_text, text}, %{team_state: team_state} = state) do
    message = Poison.decode!(text)
    Logger.debug "incomming message: #{inspect message}"

    case valid_command?(message, team_state) do
      {:ok, {cmd, args, _channel}} ->
        Logger.debug "valid message: #{cmd} #{args}"
        send(SlackBot.PluginServer, {:recv_command, cmd, args, message})
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

  def handle_cast({:send_dm, msg, user}, %{websocket: websocket, last_id: last_id, dm_channels: dm_channels} = state) do
    case get_dm_channel(user, dm_channels) do
      {:ok, channel} ->
        payload = Poison.encode!(%{id: last_id + 1, type: "message", text: msg, channel: channel})
        websocket |> WebsocketClient.send({:text, payload})
      {:error, reason} ->
        Logger.warn "direct message to #{user} failed: #{reason}"
    end

    {:noreply, state}
  end

  # private

  defp valid_command?(message, team_state) do
    self_id = team_state |> Map.get("self") |> Map.get("id")

    # TODO: exclude old message
    with {:ok, "message"} <- Map.fetch(message, "type"),
         :error <- Map.fetch(message, "subtype"),
         {:ok, channel} <- Map.fetch(message, "channel"),
         {:ok, text} <- Map.fetch(message, "text"),
         %{"cmd" => cmd, "args" => args} <-
           parse_with_mention(self_id, text) || parse_in_dm(channel, text),
      do:
         {:ok, {cmd, args, channel}}
  end

  defp parse_with_mention(self_id, text) do
    Regex.named_captures(~r/<@#{self_id}> (?<cmd>\w+)( +(?<args>.*))?/, text)
  end

  defp parse_in_dm(channel, text) do
    String.starts_with?(channel, "D") &&
      Regex.named_captures(~r/(?<cmd>\w+)( +(?<args>.*))?/, text)
  end

  defp get_dm_channel(user, dm_channels) do
    case :ets.lookup(dm_channels, user) do
      [{^user, channel} | _] ->
        {:ok, channel}
      _ ->
        case open_dm_channel(user) do
          {:ok, channel} ->
            :ets.insert(dm_channels, {user, channel})
            {:ok, channel}
          error ->
            error
        end
    end
  end

  defp open_dm_channel(user) do
    case SlackBot.WebAPI.get("im.open", %{user: user}) do
      {:ok, res} ->
        case Poison.decode(res.body) do
          {:ok, %{"channel" => %{"id" => channel}}} ->
            {:ok, channel}
          _ ->
            {:error, "invalid response #{inspect res}"}
        end
      _ ->
        {:error, "im.open #{user} failed"}
    end
  end

end
