defmodule Showish.Accounts.UserToken do
  @moduledoc """
  Opaque tokens that stand in for a password once someone has logged in.

  The raw token lives in the session cookie; only its SHA-256 digest is stored,
  so a leaked database dump cannot be replayed as a login.
  """

  use Ecto.Schema

  import Ecto.Query

  alias Showish.Accounts.User
  alias Showish.Accounts.UserToken

  @rand_size 32

  # Long enough that an operator is not logged out mid-season.
  @session_validity_in_days 60

  schema "users_tokens" do
    field :token, :binary
    field :context, :string

    belongs_to :user, User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc "How long a session token stays good for, in days."
  def session_validity_in_days, do: @session_validity_in_days

  @doc """
  Builds a session token, returning `{raw_token, struct_to_insert}`.

  The raw token is handed to the browser; the struct keeps only the digest.
  """
  def build_session_token(%User{} = user) do
    token = :crypto.strong_rand_bytes(@rand_size)

    {token,
     %UserToken{
       token: :crypto.hash(:sha256, token),
       context: "session",
       user_id: user.id
     }}
  end

  @doc "Query returning the user a still-valid session token belongs to."
  def verify_session_token_query(token) do
    hashed = :crypto.hash(:sha256, token)

    from token in by_token_and_context_query(hashed, "session"),
      join: user in assoc(token, :user),
      where: token.inserted_at > ago(@session_validity_in_days, "day"),
      select: user
  end

  @doc "Query for one token in one context."
  def by_token_and_context_query(token, context) do
    from UserToken, where: [token: ^token, context: ^context]
  end

  @doc "Query for every token a user holds in the given contexts."
  def by_user_and_contexts_query(%User{id: user_id}, :all) do
    from t in UserToken, where: t.user_id == ^user_id
  end

  def by_user_and_contexts_query(%User{id: user_id}, contexts) when is_list(contexts) do
    from t in UserToken, where: t.user_id == ^user_id and t.context in ^contexts
  end
end
