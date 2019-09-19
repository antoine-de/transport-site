defmodule Transport.Commune do
  @moduledoc """
  Commune schema
  """
  use Ecto.Schema
  import Ecto.Query
  alias Transport.{AOM, Repo}

  schema "commune" do
      field :insee, :string
      field :nom, :string
      field :wikipedia, :string
      field :surf_ha, :float
      field :geom, Geo.PostGIS.Geometry

      belongs_to :aom_res, AOM, references: :composition_res_id
  end

  def search(q) do
    res = Transport.CommunesIndex.search(q)
    IO.inspect(res)

    __MODULE__
    |> where([d], d.id in ^res)
    |> order_by([d], fragment("array_position(?::bigint[], ?)", ^res, d.id))
    |> Repo.all

  end
end
