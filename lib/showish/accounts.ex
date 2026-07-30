defmodule Showish.Accounts do
  @moduledoc """
  Accounts and the sessions they sign in with.

  Identity comes from Google — see `Showish.Accounts.Google` — so there is no
  password here to store, reset or leak. This module turns a Google profile into
  a `Showish.Accounts.User`, and a user into the session token the browser
  carries.

  Who is allowed to see which show is a question for `Showish.Broadcasts`, which
  takes a `Showish.Accounts.Scope` built from the user this module hands back.
  """

  import Ecto.Query, warn: false

  alias Showish.Accounts.User
  alias Showish.Accounts.UserToken
  alias Showish.Repo

  ## Reading

  @doc "Fetches a user by email, or `nil`."
  def get_user_by_email(email) when is_binary(email), do: Repo.get_by(User, email: email)

  @doc "Fetches a user by their Google subject id, or `nil`."
  def get_user_by_google_id(google_id) when is_binary(google_id),
    do: Repo.get_by(User, google_id: google_id)

  @doc "Fetches a user by id, raising if they are missing."
  def get_user!(id), do: Repo.get!(User, id)

  ## Signing in

  @doc """
  Finds or creates the account a Google profile belongs to.

  In order:

    * the subject id is known — sign them in, refreshing the name and picture in
      case they have changed them at Google, and the address in case they have
      changed that too;
    * the address belongs to an account that has never signed in — a
      provisioned account, claimed here;
    * the address belongs to an account that signs in with a *different* Google
      account — refused. Google does not hand the same verified address to two
      live accounts, so this is not a person who changed their mind; handing the
      shows over on the strength of a matching address would be a way in.
    * otherwise — a new account.

  Only ever called with a profile `Showish.Accounts.Google` has already checked,
  including that Google considers the address verified.
  """
  def sign_in_with_google(%{google_id: google_id, email: email} = profile)
      when is_binary(google_id) and is_binary(email) do
    case get_user_by_google_id(google_id) || get_user_by_email(email) do
      %User{google_id: ^google_id} = user -> update_from_google(user, profile)
      %User{google_id: nil} = user -> update_from_google(user, profile)
      %User{} -> {:error, :email_taken}
      nil -> update_from_google(%User{}, profile)
    end
  end

  defp update_from_google(user, profile) do
    user
    |> User.google_changeset(profile)
    |> Repo.insert_or_update()
  end

  @doc """
  Creates an account for someone who has not signed in yet.

  Their first sign-in with a matching verified Google address claims the row,
  shows and all. Used by the seeds, and handy for handing a colleague a show
  before they have ever opened Showish.
  """
  def provision_user(attrs) do
    %User{}
    |> User.provision_changeset(attrs)
    |> Repo.insert()
  end

  ## Session tokens

  @doc "Issues a session token for `user` and returns the raw token."
  def generate_user_session_token(%User{} = user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc "The user a session token belongs to, or `nil` if it is unknown or expired."
  def get_user_by_session_token(token) when is_binary(token) do
    token
    |> UserToken.verify_session_token_query()
    |> Repo.one()
  end

  def get_user_by_session_token(_token), do: nil

  @doc "Revokes a session token."
  def delete_user_session_token(token) when is_binary(token) do
    :sha256
    |> :crypto.hash(token)
    |> UserToken.by_token_and_context_query("session")
    |> Repo.delete_all()

    :ok
  end

  @doc "Revokes every session a user holds, signing them out everywhere."
  def delete_all_user_session_tokens(%User{} = user) do
    user
    |> UserToken.by_user_and_contexts_query(:all)
    |> Repo.delete_all()

    :ok
  end
end
