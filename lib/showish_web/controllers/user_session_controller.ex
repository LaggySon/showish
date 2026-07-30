defmodule ShowishWeb.UserSessionController do
  @moduledoc """
  Ending a session.

  Starting one is Google's business — see `ShowishWeb.GoogleAuthController` —
  but signing out is ours, and it needs a real HTTP response to clear the
  cookie.
  """

  use ShowishWeb, :controller

  alias ShowishWeb.UserAuth

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Signed out.")
    |> UserAuth.log_out_user()
  end
end
