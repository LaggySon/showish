defmodule ShowishWeb.ErrorJSONTest do
  use ShowishWeb.ConnCase, async: true

  test "renders 404" do
    assert ShowishWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert ShowishWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
