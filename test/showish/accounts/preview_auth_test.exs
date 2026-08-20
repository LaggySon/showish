defmodule Showish.Accounts.PreviewAuthTest do
  use Showish.DataCase, async: true

  alias Showish.Accounts.PreviewAuth

  @return_to "https://showish-showish-pr-42.up.railway.app/auth/google/preview/callback"

  describe "valid_return_to?/1" do
    test "accepts this project's generated Railway PR callback" do
      assert PreviewAuth.valid_return_to?(@return_to)
    end

    test "rejects lookalike hosts, non-TLS URLs, and other paths" do
      refute PreviewAuth.valid_return_to?(
               "https://showish-showish-pr-42.up.railway.app.evil.test/auth/google/preview/callback"
             )

      refute PreviewAuth.valid_return_to?(
               "http://showish-showish-pr-42.up.railway.app/auth/google/preview/callback"
             )

      refute PreviewAuth.valid_return_to?(
               "https://showish-showish-pr-42.up.railway.app/auth/google/callback"
             )
    end
  end

  describe "one-time codes" do
    test "a code is bound to its callback and browser nonce and can only be used once" do
      profile = %{
        google_id: "google-preview-42",
        email: "preview@example.com",
        name: "Preview Operator",
        avatar_url: "https://example.com/avatar.png"
      }

      assert {:ok, code} = PreviewAuth.issue_code(profile, @return_to, "browser-nonce")
      refute inspect(Showish.Repo.all(Showish.Accounts.PreviewAuthCode)) =~ code

      assert {:error, :invalid_or_expired} =
               PreviewAuth.consume_code(code, @return_to, "another-nonce")

      assert {:ok, ^profile} = PreviewAuth.consume_code(code, @return_to, "browser-nonce")

      assert {:error, :invalid_or_expired} =
               PreviewAuth.consume_code(code, @return_to, "browser-nonce")
    end
  end
end
