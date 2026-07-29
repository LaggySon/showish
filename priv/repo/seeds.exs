# Seeds a demo show so there is something on screen the first time you open the
# control room.
#
#     mix run priv/repo/seeds.exs

alias Showish.Broadcasts

slug = "demo"

if show = Broadcasts.get_show_by_slug(slug) do
  {:ok, _show} = Broadcasts.delete_show(show)
end

{:ok, show} =
  Broadcasts.create_show(%{
    "slug" => slug,
    "title" => "Showish Invitational",
    "subtitle" => "Week 5",
    "stage" => "Grand Finals",
    "best_of" => 5,
    "accent_color" => "#22d3ee",
    "ticker" => "Welcome to the Showish Invitational · Grand Finals · Best of 5",
    "break_message" => "Back after a short break",
    "starts_at" => DateTime.add(DateTime.utc_now(), 15 * 60, :second),
    "show_sides" => true,
    "teams" => [
      %{
        "position" => 1,
        "name" => "Harbour Kings",
        "short_name" => "Kings",
        "code" => "HRB",
        "record" => "12-2",
        "score" => 2,
        "side" => "Attack",
        "primary_color" => "#2563eb",
        "secondary_color" => "#f8fafc"
      },
      %{
        "position" => 2,
        "name" => "Ridgeline Foxes",
        "short_name" => "Foxes",
        "code" => "RDG",
        "record" => "10-4",
        "score" => 1,
        "side" => "Defense",
        "primary_color" => "#e11d48",
        "secondary_color" => "#fff7ed"
      }
    ],
    "games" => [
      %{
        "name" => "Old Harbour",
        "mode" => "Control",
        "winner" => "a",
        "completed" => true,
        "score_a" => 2,
        "score_b" => 1
      },
      %{
        "name" => "Sable Flats",
        "mode" => "Escort",
        "winner" => "b",
        "completed" => true,
        "score_a" => 1,
        "score_b" => 3
      },
      %{
        "name" => "Ninth Ward",
        "mode" => "Hybrid",
        "winner" => "a",
        "completed" => true,
        "score_a" => 3,
        "score_b" => 2
      },
      %{"name" => "Cinder Bay", "mode" => "Push"},
      %{"name" => "Glass Quarter", "mode" => "Control"}
    ],
    "talents" => [
      %{"role" => "Host", "name" => "Ada Whitlock", "pronouns" => "she/her", "social" => "@adawhit"},
      %{"role" => "Caster", "name" => "Bo Ferreira", "pronouns" => "he/him", "social" => "@bocasts"},
      %{"role" => "Caster", "name" => "Sam Okoye", "pronouns" => "they/them", "social" => "@samok"},
      %{
        "role" => "Observer",
        "name" => "Nina Alvarez",
        "pronouns" => "she/her",
        "social" => "@ninaobs"
      },
      %{
        "role" => "Producer",
        "name" => "Kit Larsen",
        "pronouns" => "they/them",
        "social" => "@kitprod"
      }
    ]
  })

{:ok, _show} = Broadcasts.set_current_game(show, 4)

IO.puts("""

Seeded the "#{slug}" show.

  Control room: #{ShowishWeb.Endpoint.url()}/shows/#{slug}/control
  Scorebug:     #{ShowishWeb.Endpoint.url()}/overlay/#{slug}/scorebug
""")
