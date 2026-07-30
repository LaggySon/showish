defmodule Showish.Accounts.User do
  @moduledoc """
  Someone who runs broadcasts: an email address, a password, and the shows they
  own.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Showish.Accounts.Password

  @type t :: %__MODULE__{}

  # Long enough to be worth having, short enough that an operator will actually
  # remember it in a truck at 3am.
  @min_password_length 12
  @max_password_length 128

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :current_password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for signing up.

  ## Options

    * `:hash_password` — set to `false` to validate without paying for key
      derivation, which is what the live form does on every keystroke.
    * `:validate_email` — set to `false` to skip the uniqueness query.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_email(opts)
    |> validate_password(opts)
  end

  @doc "Changeset for changing an email address."
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _email}} = changeset ->
        changeset

      changeset ->
        add_error(changeset, :email, "did not change")
    end
  end

  @doc "Changeset for changing a password."
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, Showish.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: @min_password_length, max: @max_password_length)
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash? && password && changeset.valid? do
      changeset
      |> put_change(:hashed_password, Password.hash(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Verifies a password against the stored hash.

  Takes the same time whether or not there is a user, so the login form gives
  nothing away about which addresses have accounts.
  """
  def valid_password?(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and is_binary(password) do
    Password.valid?(password, hashed_password)
  end

  def valid_password?(_user, _password), do: Password.no_user_verify()

  @doc """
  Adds an error to `:current_password` unless it really is the current password.

  Used by the settings form, so that someone who walks up to an unattended
  laptop cannot quietly take the account over.
  """
  def validate_current_password(changeset, password) do
    changeset = cast(changeset, %{current_password: password}, [:current_password])

    if valid_password?(changeset.data, password || "") do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end
end
