defmodule Showish.AccountsTest do
  use Showish.DataCase, async: true

  import Showish.AccountsFixtures

  alias Showish.Accounts
  alias Showish.Accounts.User

  describe "register_user/1" do
    test "requires an email and a password" do
      assert {:error, changeset} = Accounts.register_user(%{})

      assert %{email: ["can't be blank"], password: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects an email without an @ and a password that is too short" do
      assert {:error, changeset} =
               Accounts.register_user(%{email: "not an email", password: "short"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
      assert "should be at least 12 character(s)" in errors_on(changeset).password
    end

    test "refuses an address that is already registered, whatever its case" do
      %{email: email} = user_fixture()

      assert {:error, changeset} = Accounts.register_user(valid_user_attributes(email: email))
      assert "has already been taken" in errors_on(changeset).email

      assert {:error, changeset} =
               Accounts.register_user(valid_user_attributes(email: String.upcase(email)))

      assert "has already been taken" in errors_on(changeset).email
    end

    test "stores a hash rather than the password" do
      email = unique_user_email()
      {:ok, user} = Accounts.register_user(valid_user_attributes(email: email))

      assert user.email == email
      assert is_binary(user.hashed_password)
      refute user.hashed_password =~ valid_user_password()
      assert is_nil(user.password)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "returns the user when the password is right" do
      %{id: id} = user = user_fixture()

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end

    test "is case-insensitive about the email" do
      user = user_fixture()

      assert Accounts.get_user_by_email_and_password(
               String.upcase(user.email),
               valid_user_password()
             )
    end

    test "returns nil for a wrong password or an unknown address" do
      user = user_fixture()

      refute Accounts.get_user_by_email_and_password(user.email, "not the password")
      refute Accounts.get_user_by_email_and_password("nobody@example.com", valid_user_password())
    end
  end

  describe "session tokens" do
    setup do
      %{user: user_fixture()}
    end

    test "a generated token identifies its user", %{user: user} do
      token = Accounts.generate_user_session_token(user)

      assert Accounts.get_user_by_session_token(token).id == user.id
    end

    test "an unknown or deleted token identifies nobody", %{user: user} do
      token = Accounts.generate_user_session_token(user)

      refute Accounts.get_user_by_session_token("made up")

      :ok = Accounts.delete_user_session_token(token)
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "update_user_email/3" do
    setup do
      %{user: user_fixture()}
    end

    test "changes the address once the current password is given", %{user: user} do
      assert {:ok, updated} =
               Accounts.update_user_email(user, valid_user_password(), %{
                 email: "new@example.com"
               })

      assert updated.email == "new@example.com"
    end

    test "refuses without the current password", %{user: user} do
      assert {:error, changeset} =
               Accounts.update_user_email(user, "wrong", %{email: "new@example.com"})

      assert "is not valid" in errors_on(changeset).current_password
      assert Accounts.get_user!(user.id).email == user.email
    end
  end

  describe "update_user_password/3" do
    setup do
      %{user: user_fixture()}
    end

    test "changes the password and logs every session out", %{user: user} do
      token = Accounts.generate_user_session_token(user)

      assert {:ok, updated} =
               Accounts.update_user_password(user, valid_user_password(), %{
                 password: "a whole new password"
               })

      refute Accounts.get_user_by_session_token(token)
      assert Accounts.get_user_by_email_and_password(updated.email, "a whole new password")
    end

    test "refuses without the current password", %{user: user} do
      assert {:error, changeset} =
               Accounts.update_user_password(user, "wrong", %{password: "a whole new password"})

      assert "is not valid" in errors_on(changeset).current_password
    end

    test "keeps the old sessions alive when the change fails", %{user: user} do
      token = Accounts.generate_user_session_token(user)

      assert {:error, _changeset} =
               Accounts.update_user_password(user, valid_user_password(), %{password: "short"})

      assert Accounts.get_user_by_session_token(token)
    end
  end
end
