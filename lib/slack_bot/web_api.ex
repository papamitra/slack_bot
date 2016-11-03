defmodule SlackBot.WebAPI do

  require Logger

  @api_uri "https://slack.com/api/"

  @spec get(atom, map) :: {atom, any}
  def get(api, map \\ %{}) do
    opts = add_proxy_opt([])
    map = add_token(map)
    uri = @api_uri <> to_string(api) <> "?" <> URI.encode_query(map)
    Logger.debug "web api get: #{uri}"
    HTTPoison.get(uri, [], opts)
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

  defp add_token(map) do
    Map.put(map, :token, Application.get_env(:slack_bot, :token))
  end

end
