defmodule SlackBot.ElixirPluginLoader do
  use GenServer

  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def load(path, mod, app) do
    GenServer.call(__MODULE__, {path, mod, app})
  end

  # callback function

  def init([]) do
    {:ok, nil}
  end

  def handle_call({path, mod, app}, _from, state) do
    compile_path = Mix.Project.in_project(app, path, [], fn _ ->
      Mix.Tasks.Loadconfig.run([])
      Mix.Tasks.Compile.run([])
      Mix.Tasks.Deps.Loadpaths.run([])
      Mix.Project.compile_path
    end)

    Code.prepend_path(compile_path)

    case Code.ensure_loaded(mod) do
      {:module, mod} ->
        Logger.debug "module load succeeded: #{mod}"
      _ ->
        Logger.warn "module load failed: #{mod}"
        exit(:load_failed)
    end

    {:reply, :ok, state}
  end

end
