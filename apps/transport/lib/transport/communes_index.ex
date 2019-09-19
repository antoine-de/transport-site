defmodule Transport.CommunesIndex do
  @moduledoc """
  load commune into tantivy search engine.
  """
  use Agent
  require Logger
  import Ecto.Query

  def start_link(_params) do
    Agent.start_link(fn -> import_cities() end, name: __MODULE__)
  end

  def tantivy do
    Agent.get(__MODULE__, & &1)
  end

  def search(query) do
    tantivy()
    |> Tantivy.search_cities(query)
    |> Enum.flat_map(& &1)
  end

  defp import_cities do
    {:ok, resource} = Tantivy.init()
    Logger.info("indexing cities")
    query = from(c in Transport.Commune, select: {c.id, c.nom, c.insee})

    Transport.Repo.transaction(fn ->
      query
      |> Transport.Repo.stream()
      # |> Stream.map(fn {id, insee, nom} -> {id, nom, insee} end)
      |> Stream.chunk_every(10000)
      |> Enum.to_list()
      |> Enum.each(&Tantivy.add_cities(resource, &1))
    end)
    Logger.info("cities indexed")
    resource
  end
end
