defmodule TransportWeb.Backoffice.PageController do
  use TransportWeb, :controller

  alias Transport.{Dataset, Region, Repo}
  import Ecto.Query
  require Logger

  ## Controller functions

  def index(%Plug.Conn{} = conn, %{"q" => q} = params) when q != "" do
    conn = assign(conn, :q, q)
    config = make_pagination_config(params)
    q
    |> Dataset.search_datasets
    |> preload([:region, :aom, :resources])
    |> Repo.paginate(page: config.page_number)
    |> render_index(conn)
  end

  def index(%Plug.Conn{} = conn, params) do
    config = make_pagination_config(params)
    Dataset
    |> preload([:region, :aom, :resources])
    |> Repo.paginate(page: config.page_number)
    |> render_index(conn)
  end

  ## Private functions
  defp region_names do
    Region
    |> Repo.all()
    |> Enum.map(fn r -> {r.nom, r.id} end)
    |> Enum.concat([{"Pas de region", nil}])
  end

  defp render_index(datasets, conn) do
    conn
    |> assign(:regions, region_names())
    |> assign(:datasets, datasets)
    |> assign(:dataset_types, Dataset.dataset_types())
    |> render("index.html")
  end
end