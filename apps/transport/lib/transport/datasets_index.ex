defmodule Transport.DatasetsIndex do
  @moduledoc """
  load dataset into tantivy search engine.
  """
  use Agent
  import Ecto.Query

  def start_link(_params) do
    Agent.start_link(fn -> import_datasets() end, name: __MODULE__)
  end

  def tantivy do
    Agent.get(__MODULE__, & &1)
  end

  def search(query) do
    tantivy()
    |> Tantivy.search(query)
    |> Enum.flat_map(& &1)
  end

  defp import_datasets do
    {:ok, resource} = Tantivy.init()
    query = from(d in Transport.Dataset, select: {d.id, d.spatial, d.description, d.title})

    Transport.Repo.transaction(fn ->
      query
      |> Transport.Repo.stream()
      |> Stream.map(fn {id, spatial, description, title} -> {id, "#{spatial} #{description} #{title}"} end)
      |> Stream.chunk_every(10000)
      |> Enum.to_list()
      |> Enum.each(&Tantivy.add_entries(resource, &1))
    end)
    resource
  end
end
