defmodule Showish.Accounts.Password do
  @moduledoc """
  Password hashing, built on the PBKDF2 that ships inside OTP's `:crypto`.

  Deliberately no extra dependency: `bcrypt_elixir` and friends are NIFs that
  need a C toolchain in every build image, and PBKDF2-HMAC-SHA512 at the
  iteration count below is what OWASP recommends. Hashes are self-describing —

      pbkdf2-sha512$210000$<base64 salt>$<base64 hash>

  so the cost can be raised later without stranding the hashes already stored.
  """

  @digest :sha512
  @salt_bytes 16
  @length 32
  @prefix "pbkdf2-sha512"

  # Tests hash a lot of throwaway passwords; config/test.exs turns this right
  # down so the suite is not dominated by key derivation.
  @iterations Application.compile_env(:showish, [__MODULE__, :iterations], 210_000)

  @doc "Hashes `password`, returning the string stored in `users.hashed_password`."
  def hash(password) when is_binary(password) do
    salt = :crypto.strong_rand_bytes(@salt_bytes)
    hash = derive(password, salt, @iterations)

    Enum.join([@prefix, @iterations, Base.encode64(salt), Base.encode64(hash)], "$")
  end

  @doc """
  Checks `password` against a stored hash, in constant time.

  Anything unparseable — including `nil`, for a user that does not exist — is
  simply a failed check.
  """
  def valid?(password, stored) when is_binary(password) and is_binary(stored) do
    with [@prefix, iterations, salt, hash] <- String.split(stored, "$"),
         {iterations, ""} <- Integer.parse(iterations),
         {:ok, salt} <- Base.decode64(salt),
         {:ok, hash} <- Base.decode64(hash) do
      Plug.Crypto.secure_compare(derive(password, salt, iterations), hash)
    else
      _other -> false
    end
  end

  def valid?(_password, _stored), do: false

  @doc """
  Burns the same time a real check would, then fails.

  Called when no user matched, so that a missing account and a wrong password
  take the same time to answer and the login form cannot be used to enumerate
  who has signed up.
  """
  def no_user_verify do
    hash("nobody has this password")
    false
  end

  defp derive(password, salt, iterations) do
    :crypto.pbkdf2_hmac(@digest, password, salt, iterations, @length)
  end
end
