defmodule Showish.Accounts do
  @moduledoc """
  Registration, login and account settings.

  Everything here deals in `Showish.Accounts.User` structs and session tokens.
  Who is allowed to see which show is a question for `Showish.Broadcasts`,
  which takes a `Showish.Accounts.Scope` built from the user this module hands
  back.
  """

  import Ecto.Query, warn: false

  alias Showish.Accounts.User
  alias Showish.Accounts.UserToken
  alias Showish.Repo

  ## Reading

  @doc "Fetches a user by email, or `nil`."
  def get_user_by_email(email) when is_binary(email), do: Repo.get_by(User, email: email)

  @doc """
  Fetches a user by email and password, or `nil`.

  Costs the same whether the address is unknown or the password is wrong.
  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)
    if User.valid_password?(user, password), do: user
  end

  @doc "Fetches a user by id, raising if they are missing."
  def get_user!(id), do: Repo.get!(User, id)

  ## Registration

  @doc "Registers a user."
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Changeset for the registration form.

  Hashing is skipped: this runs on every keystroke and key derivation is meant
  to be slow.
  """
  def change_user_registration(%User{} = user \\ %User{}, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc "Changeset for the email form."
  def change_user_email(%User{} = user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Updates a user's email address, once they have proved they know the current
  password.
  """
  def update_user_email(%User{} = user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Repo.update()
  end

  @doc "Changeset for the password form."
  def change_user_password(%User{} = user, attrs \\ %{}, opts \\ [hash_password: false]) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates a user's password and logs every other session out.

  Returns `{:ok, user}` or `{:error, changeset}`. The tokens go in the same
  transaction as the new password, so a half-applied change cannot leave an old
  session alive.
  """
  def update_user_password(%User{} = user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _changes} -> {:error, changeset}
    end
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
end
