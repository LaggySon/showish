# Example data: an esports show and a baseball show, so there is something on
# screen the first time you open the control room.
#
#     mix run priv/repo/seeds.exs
#
# Here the examples are reset to how they ship. See Showish.Seeds for who owns
# them (SEED_EMAIL, else the first ALLOWED_GOOGLE_EMAILS address, else
# operator@example.com) and for how PR previews seed themselves.

results = Showish.Seeds.run(reset: true)
email = Showish.Seeds.owner_email()

for result <- results do
  case result do
    {:skipped, slug, :owned_by_someone_else} ->
      IO.puts("Skipped #{slug}: that slug belongs to another account.")

    {what, slug} ->
      IO.puts("#{what |> Atom.to_string() |> String.capitalize()} #{slug}.")
  end
end

IO.puts("""

The examples belong to #{email}. Sign in with Google as #{email} to claim them.

  Control room: #{ShowishWeb.Endpoint.url()}/shows/demo/control
  Scorebug:     #{ShowishWeb.Endpoint.url()}/overlay/demo/scorebug
  Baseball:     #{ShowishWeb.Endpoint.url()}/shows/demo-baseball/control
""")
