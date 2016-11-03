defmodule SlackBot do
  use GenServer

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

  # callback function

  def init([url, team_state]) do
    SlackBot.PluginsSupervisor.start_link(team_state)
    {:ok, websocket} = WebsocketClient.start_link(self, url)
    {:ok, %{websocket: websocket, team_state: team_state, last_id: 0}}
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

  # private

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
