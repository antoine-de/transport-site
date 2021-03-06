defmodule TransportWeb.BackofficeController do
  use TransportWeb, :controller

  alias Datagouvfr.Client.Datasets
  alias Transport.{AOM, Dataset, ImportDataService, Partner, Region, Repo, Resource}
  import Ecto.Query
  require Logger

  @dataset_types [
    {dgettext("backoffice", "transport static"), "transport-statique"},
    {dgettext("backoffice", "carsharing areas"), "aires-covoiturage"},
    {dgettext("backoffice", "stops referential"), "stops-ref"},
    {dgettext("backoffice", "charging stations"), "bornes-recharge"},
    {dgettext("backoffice", "bike sharing"), "bike-sharing"}
  ]

  def index(%Plug.Conn{} = conn, %{"q" => q} = params) when q != "" do
    config = make_pagination_config(params)
    datasets =
      q
      |> Dataset.search_datasets
      |> preload([:region, :aom, :resources])
      |> Repo.paginate(page: config.page_number)

    conn
    |> assign(:regions, region_names())
    |> assign(:datasets, datasets)
    |> assign(:q, q)
    |> assign(:dataset_types, @dataset_types)
    |> render("index.html")
  end

  def index(%Plug.Conn{} = conn, params) do
    config = make_pagination_config(params)
    datasets =
      Dataset
      |> preload([:region, :aom, :resources])
      |> Repo.paginate(page: config.page_number)

    conn
    |> assign(:regions, region_names())
    |> assign(:datasets, datasets)
    |> assign(:dataset_types, @dataset_types)
    |> render("index.html")
  end

  def new_dataset(%Plug.Conn{} = conn, params) do
    with datagouv_id <- Datasets.get_id_from_url(conn, params["url"]),
         {:ok, aom_id} <- get_aom_id(params),
         {:ok, datagouv_dataset} <- ImportDataService.import_from_udata(datagouv_id, params["type"]),
         params <- Map.put(params, "aom_id", aom_id),
         params <- Map.merge(params, datagouv_dataset),
         changeset <- Dataset.changeset(%Dataset{}, params),
         {:ok, _dataset} <- Repo.insert(changeset)
    do
      conn
      |> put_flash(:info, dgettext("backoffice", "Dataset added with success"))
    else
      {:error, error} ->
        conn
        |> put_flash(:error, dgettext("backoffice", "Could not add dataset"))
        |> put_flash(:error, error)
    end
    |> redirect(to: backoffice_path(conn, :index))
  end

  def import_from_data_gouv_fr(%Plug.Conn{} = conn, %{"id" => id}) do
    Dataset
    |> Repo.get(id)
    |> import_data
    |> flash(conn,
            dgettext("backoffice", "Dataset imported with success"),
            dgettext("backoffice", "Dataset not imported")
      )
    |> redirect(to: backoffice_path(conn, :index))
  end

  def delete(%Plug.Conn{} = conn, %{"id" => id}) do
    Dataset
    |> Repo.get(id)
    |> Repo.delete()
    |> flash(conn, dgettext("backoffice", "Dataset deleted"), dgettext("backoffice", "Could not delete dataset"))
    |> redirect(to: backoffice_path(conn, :index))
  end

  def validation(%Plug.Conn{} = conn, %{"id" => id}) do
    Resource
    |> where([r], r.dataset_id ==  ^id)
    |> Repo.all()
    |> Enum.reduce(conn,
      fn r, conn -> r
        |> Resource.validate_and_save()
        |> flash(conn,
          dgettext("backoffice", "Dataset validated"),
          dgettext("backoffice", "Could not validate dataset")
        )
      end
    )
    |> redirect(to: backoffice_path(conn, :index))
  end

  def partners(%Plug.Conn{} = conn, params) do
    config = make_pagination_config(params)
    partners = Repo.paginate(Partner, page: config.page_number)

    conn
    |> assign(:partners, partners)
    |> render("partners.html")
  end

  def post_partner(%Plug.Conn{} = conn, %{"id" => partner_id, "action" => "delete"}) do
    partner = Repo.get(Partner, partner_id)

    case Repo.delete(partner) do
      {:ok, _} ->
        conn
        |> put_flash(:info, dgettext("backoffice", "Partner deleted"))
        |> redirect(to: backoffice_path(conn, :partners))
      {:error, error} ->
        Logger.error(error)
        conn
        |> put_flash(:error, dgettext("backoffice", "Unable to delete"))
        |> redirect(to: backoffice_path(conn, :partners))
    end
  end

  def post_partner(%Plug.Conn{} = conn, %{"partner_url" => partner_url}) do
    with true <- Partner.is_datagouv_partner_url?(partner_url),
         {:ok, partner} <- Partner.from_url(partner_url),
         {:ok, _} <- Repo.insert(partner) do
      put_flash(conn, :info, dgettext("backoffice", "Partner added"))
    else
      false ->
        put_flash(conn, :error, dgettext("backoffice", "This has to be an organization or a user"))
      {:error, error} ->
        Logger.error(error)
        put_flash(conn, :error, dgettext("backoffice", "Unable to insert partner in database"))
    end
    |> redirect(to: backoffice_path(conn, :partners))
  end

  ## private

  defp region_names do
    Region
    |> Repo.all()
    |> Enum.map(fn r -> {r.nom, r.id} end)
    |> Enum.concat([{"National", nil}])
  end

  defp import_data(%Dataset{} = dataset), do: import_data({:ok, dataset})
  defp import_data(nil), do: {:error, dgettext("backoffice", "Unable to find dataset")}
  defp import_data({:ok, dataset}), do: ImportDataService.call(dataset)
  defp import_data(error), do: error

  defp flash({:ok, _message}, conn, ok_message, err_message), do: flash(:ok, conn, ok_message, err_message)
  defp flash(:ok,  conn, ok_message, _err_message) do
    put_flash(conn, :info, ok_message)
  end

  defp flash({:error, %{errors: errors}}, conn, _ok_message, err_message) do
    Enum.reduce(errors, conn,
     fn {k, {error, _}}, conn -> put_flash(conn, :error, "#{err_message} #{k}: #{error}") end
    )
  end

  defp flash({:error, message}, conn, _ok_message, err_message) do
    put_flash(conn, :error, "#{err_message} (#{message})")
  end

  defp get_aom_id(%{"insee_commune_principale" => nil}), do: {:ok, nil}
  defp get_aom_id(%{"insee_commune_principale" => ""}), do: {:ok, nil}
  defp get_aom_id(%{"insee_commune_principale" => insee}) do
    case Repo.get_by(AOM, insee_commune_principale: insee) do
      nil -> {:error, dgettext("backoffice", "Unable to find INSEE")}
      aom -> {:ok, aom.id}
    end
  end
end
