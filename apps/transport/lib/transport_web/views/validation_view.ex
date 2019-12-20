defmodule TransportWeb.ValidationView do
  use TransportWeb, :view
  import Phoenix.Controller, only: [current_url: 1]
  import TransportWeb.ResourceView, only: [issue_type: 1, template: 1]
  import TransportWeb.PaginationHelpers

  def render("_" <> _ = partial, assigns) do
    render(TransportWeb.ResourceView, partial, assigns)
  end

  def has_errors?(errors) do
    errors
    |> Enum.reject(fn error -> match?({"Irrelevant", _}, error) end)
    |> Enum.empty?()
    |> Kernel.not()
  end
end
