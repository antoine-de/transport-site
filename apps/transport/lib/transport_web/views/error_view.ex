defmodule TransportWeb.ErrorView do
  use TransportWeb, :view

  def render("500.html", assigns) do
    render(__MODULE__, "internal_server_error.html", assigns)
  end

  def render("400.html", assigns) do
    render(__MODULE__, "internal_server_error.html", assigns)
  end

  def render("404.html", assigns) do
    render(__MODULE__, "not_found_error.html", assigns)
  end
end
