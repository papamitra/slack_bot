defmodule SlackBot do
  use WebsocketClient

  require Logger

  def rtm_start do
    token = Application.get_env(:slack_bot, :token)
    opts = add_proxy_opt([])
    res = HTTPoison.get!("https://slack.com/api/rtm.start?token=#{token}", [], opts)

    %{"url" => url} = Poison.decode!(res.body)

    WebsocketClient.start_link(__MODULE__, url)
  end

  def send_message(pid, msg) do
    
  end

  # callback function

  def init(_args) do
    plugins = Enum.map(Application.get_env(:slack_bot, :plugins), fn %{path: path, mod: mod} ->
      try do
        Code.append_path(path)
        {:module, mod}= Code.ensure_loaded(mod)

        {:ok, pid} = apply(mod, :start, [self])
        {mod, pid}
      rescue
        error ->
          Logger.warn "plugin loading failed: #{mod}, #{error}"
          nil
      end
    end) |> Enum.filter(fn x -> not is_nil(x) end)

    {:ok, %{plugins: plugins}}
  end

  def handle_text(text, %{plugins: plugins} = state) do
    Enum.each(plugins, fn({mod, pid}) ->
      try do
        apply(mod, :handle_text, [pid, text])
      rescue
        error ->
          Logger.warn "#{mod}.handle_text failed: #{error}"
      end
    end)
    {:ok, state}
  end

  # private

  defp add_proxy_opt(acc) do
    https_proxy = System.get_env("https_proxy")
    case  https_proxy |> URI.parse do
      %URI{host: proxy_host} when not is_nil(proxy_host) ->
        Logger.info "use proxy: #{https_proxy}"
        [{:proxy, https_proxy} | acc]
      _ ->
        acc
    end
  end

end
