defmodule SlackBot do
  use WebsocketClient

  def rtm_start do
    token = Application.get_env(:slack_bot, :token)
    opts = add_proxy_opt([])
    res = HTTPoison.get!("https://slack.com/api/rtm.start?token=#{token}", [], opts)

    %{"url" => url} = Poison.decode!(res.body)

    WebsocketClient.start_link(__MODULE__, url)
  end


  defp add_proxy_opt(acc) do
    https_proxy = System.get_env("https_proxy")
    case  (https_proxy || "") |> URI.parse do
      %URI{host: proxy_host} when not is_nil(proxy_host) ->
        [{:proxy, https_proxy} | acc]
      _ ->
        acc
    end
  end

  # callback function

  def init(_args) do
    {:ok, []}
  end

  def handle_text(text, state) do
    IO.puts "get text: #{text}"
    {:ok, state}
  end

end
