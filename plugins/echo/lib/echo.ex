defmodule SlackBot.Plugin.Echo do
  use GenServer

  def start(parent) do
    IO.puts "start echo plugin"

    GenServer.start_link(__MODULE__, parent)
  end

  # callback function

  def init(parent) do
    {:ok, %{parent: parent}}
  end

  def handle_text(pid, text) do
    IO.puts "Echo: handle_text"
    IO.puts text
  end

end
