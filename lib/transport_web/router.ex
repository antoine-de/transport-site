defmodule TransportWeb.Router do
  use TransportWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_locale
    plug :assign_current_user
    plug :assign_contact_email
    plug :assign_token
  end

  pipeline :json_api do
    plug :accepts, ["jsonapi"]
    plug JaSerializer.ContentTypeNegotiation
    plug JaSerializer.Deserializer
  end

  pipeline :accept_json do
    plug :accepts, ["json"]
  end

  pipeline :api_authenticated do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :fetch_flash
    plug :assign_current_user
    plug :assign_token
    plug :authentication_required
  end

  scope "/", TransportWeb do
    pipe_through :browser

    get "/", PageController, :index
    get "/search_organizations", PageController, :search_organizations
    post "/send_mail", ContactController, :send_mail

    scope "/datasets" do
      get "/", DatasetController, :index
      get "/:slug/", DatasetController, :details
    end

    scope "/user" do
      pipe_through [:authentication_required]
      get "/organizations/", UserController, :organizations
      get "/organizations/form", UserController, :organization_form
      post "/organizations/_create", UserController, :organization_create
      get "/organizations/:slug/datasets/", UserController, :organization_datasets
      get "/organizations/:slug/datasets/new", DatasetController, :new
      post "/organizations/:organization/datasets/_create", DatasetController, :create
      post "/organizations/:organization/datasets/_create_community_resource", DatasetController, :create_community_resource
      get "/datasets/:slug/_add", UserController, :add_badge_dataset
    end

    # Authentication

    scope "/login" do
      get "/", SessionController, :new
      get "/explanation", PageController, :login
      get "/callback", SessionController, :create
    end

    get "/logout", SessionController, :delete

    # Admin dashboard

    scope "/admin", Admin, as: :admin do
      get "/datasets", DatasetController, :index
      post "/datasets/validate", DatasetController, :validate
      post "/datasets/fetch_validation", DatasetController, :fetch_validation
    end
  end

  scope "/api", TransportWeb do

    scope "/datasets" do
      pipe_through :json_api
      get "/", API.DatasetController, :index
      get "/:slug/", API.DatasetController, :show
    end

    scope "/datasets" do
      pipe_through :accept_json
      get "/:slug/validations/", API.DatasetController, :validations
    end

    scope "/datasets" do
      pipe_through :api_authenticated
      post "/:dataset_id/followers/", API.FollowerController, :create
      delete "/:dataset_id/followers/", API.FollowerController, :delete
    end

    scope "/discussions" do
      pipe_through :api_authenticated
      post "/", API.DiscussionController, :post_discussion
      post "/:id_", API.DiscussionController, :post_discussion
    end
  end

  # private

  defp put_locale(conn, _) do
    case conn.params["locale"] || get_session(conn, :locale) do
      nil ->
        TransportWeb.Gettext |> Gettext.put_locale("fr")
        conn |> put_session(:locale, "fr")
      locale  ->
        TransportWeb.Gettext |> Gettext.put_locale(locale)
        conn |> put_session(:locale, locale)
    end
  end

  defp assign_current_user(conn, _) do
    assign(conn, :current_user, get_session(conn, :current_user))
  end

  defp assign_contact_email(conn, _) do
    assign(conn, :contact_email, "contact@transport.beta.gouv.fr")
  end

  defp assign_token(conn, _) do
    assign(conn, :token, get_session(conn, :token))
  end

  defp authentication_required(conn, _) do
    case conn.assigns[:current_user]  do
      nil ->
        conn
            |> put_flash(:info, dgettext("alert", "You need to be connected before doing this."))
            |> redirect(to: Helpers.page_path(conn, :login,
                        redirect_path: current_path(conn)))
            |> halt()
      _ ->
        conn
    end
  end
end
