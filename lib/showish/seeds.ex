defmodule Showish.Seeds do
  @moduledoc """
  Example data: one show per sport, filled in far enough that every scene has
  something to draw, and two example themes for the Look menu.

  Used three ways:

    * `mix run priv/repo/seeds.exs` on a laptop, which resets the examples to
      how they ship;
    * `bin/seed` in a release, which every PR preview runs after its
      migrations (see `railway.json`). It only creates what is missing, so a
      reviewer's changes survive the next push to the PR;
    * the tests, which check that both of the above work.

  ## Who owns the examples

  Shows belong to an account, and sign-in is Google's job, so the owner is
  provisioned by address: the first time someone signs in with that Google
  address, the account and its example shows are theirs. The address is
  `SEED_EMAIL` if set, otherwise the first address in `ALLOWED_GOOGLE_EMAILS`
  (which every PR preview has, so the examples land in the account of whoever
  is allowed to review it), otherwise `operator@example.com`.

  Overlay slugs are unique across all accounts, so an example whose slug
  belongs to somebody else is left alone rather than taken over.
  """

  alias Showish.Accounts
  alias Showish.Accounts.Allowlist
  alias Showish.Accounts.Scope
  alias Showish.Broadcasts
  alias Showish.Broadcasts.Show
  alias Showish.Themes

  @doc """
  Creates the example shows for the owner (see above), returning a line per
  show saying what happened to it.

  With `reset: true`, an example that already exists is deleted and made again
  from scratch; otherwise it is kept as it is.
  """
  def run(opts \\ []) do
    reset? = Keyword.get(opts, :reset, false)
    email = Keyword.get_lazy(opts, :email, &owner_email/0)
    scope = email |> owner() |> Scope.for_user()

    shows =
      for {slug, build} <- [{"demo", &esports/1}, {"demo-baseball", &baseball/1}] do
        seed(scope, slug, build, reset?)
      end

    shows ++ Enum.map(example_themes(), &seed_theme(scope, &1, reset?))
  end

  @doc "The address the examples are made for. See the moduledoc."
  def owner_email do
    case {System.get_env("SEED_EMAIL"), Allowlist.emails()} do
      {email, _list} when is_binary(email) and email != "" -> String.trim(email)
      {_none, [first | _rest]} -> first
      {_none, []} -> "operator@example.com"
    end
  end

  defp owner(email) do
    case Accounts.get_user_by_email(email) do
      nil ->
        {:ok, user} = Accounts.provision_user(%{"email" => email})
        user

      user ->
        user
    end
  end

  defp seed(%Scope{user: user} = scope, slug, build, reset?) do
    case Broadcasts.get_public_show_by_slug(slug) do
      nil ->
        build.(scope)
        {:created, slug}

      %Show{user_id: owner} when owner != user.id ->
        {:skipped, slug, :owned_by_someone_else}

      %Show{} = show when reset? ->
        {:ok, _show} = Broadcasts.delete_show(scope, show)
        build.(scope)
        {:reset, slug}

      %Show{} ->
        {:kept, slug}
    end
  end

  # Themes are per account, so one with the example's name is the example: the
  # same rules as a show, keyed by name instead of slug.
  defp seed_theme(scope, %{"name" => name} = attrs, reset?) do
    label = "#{name} (theme)"

    case Enum.find(Themes.list_themes(scope), &(&1.name == name)) do
      nil ->
        {:ok, _theme} = Themes.create_theme(scope, attrs)
        {:created, label}

      theme when reset? ->
        {:ok, _theme} = Themes.delete_theme(scope, theme)
        {:ok, _theme} = Themes.create_theme(scope, attrs)
        {:reset, label}

      _theme ->
        {:kept, label}
    end
  end

  # Two themes to pick from any show's Look menu: one changing nearly every
  # token on Broadcast, with a little custom CSS, and a quieter one on Laggish.
  defp example_themes do
    [
      %{
        "name" => "Acme Esports",
        "base" => "broadcast",
        "tokens" => %{
          "panel_color" => "#101a3a",
          "panel_opacity" => 0.96,
          "border_color" => "#ffd400",
          "border_width" => 2,
          "shadow" => "hard",
          "radius" => 0,
          "text_color" => "#ffffff",
          "grays" => "zinc",
          "font" => "oswald",
          "numbers_font" => "geist-mono",
          "entrance" => "fade"
        },
        "css" => """
        /* Name plates underline in the brand yellow rather than the accent. */
        .overlay-talent {
          border-bottom-color: #ffd400;
        }
        """
      },
      %{
        "name" => "Ballpark",
        "base" => "laggish",
        "tokens" => %{
          "panel_color" => "#0f2a1d",
          "panel_opacity" => 1,
          "radius" => 6,
          "font" => "heebo",
          "grays" => "stone"
        }
      }
    ]
  end

  # A best-of-five three games in, with the whole desk and crew filled in.
  defp esports(scope) do
    {:ok, show} =
      Broadcasts.create_show(scope, %{
        "slug" => "demo",
        "title" => "Showish Invitational",
        "subtitle" => "Week 5",
        "stage" => "Grand Finals",
        "best_of" => 5,
        "accent_color" => "#22d3ee",
        "ticker" => "Welcome to the Showish Invitational · Grand Finals · Best of 5",
        "break_message" => "Back after a short break",
        "starts_at" =>
          DateTime.add(DateTime.utc_now(), 15 * 60, :second) |> DateTime.truncate(:second),
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
            "secondary_color" => "#f8fafc",
            "logo_url" => "/images/teams/harbour-kings.svg"
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
            "secondary_color" => "#fff7ed",
            "logo_url" => "/images/teams/ridgeline-foxes.svg"
          }
        ],
        "games" => [
          %{
            "name" => "Old Harbour",
            "mode" => "Control",
            "image_url" => "/images/maps/old-harbour.svg",
            "winner" => "a",
            "completed" => true,
            "score_a" => 2,
            "score_b" => 1
          },
          %{
            "name" => "Sable Flats",
            "mode" => "Escort",
            "image_url" => "/images/maps/sable-flats.svg",
            "winner" => "b",
            "completed" => true,
            "score_a" => 1,
            "score_b" => 3
          },
          %{
            "name" => "Ninth Ward",
            "mode" => "Hybrid",
            "image_url" => "/images/maps/ninth-ward.svg",
            "winner" => "a",
            "completed" => true,
            "score_a" => 3,
            "score_b" => 2
          },
          %{
            "name" => "Cinder Bay",
            "mode" => "Push",
            "image_url" => "/images/maps/cinder-bay.svg"
          },
          %{
            "name" => "Glass Quarter",
            "mode" => "Control",
            "image_url" => "/images/maps/glass-quarter.svg"
          }
        ],
        # The host and casters are on camera; the observer and producer are on the
        # crew but not on the desk, which is what `on_cam` is for.
        "talents" => [
          %{
            "role" => "Host",
            "name" => "Ada Whitlock",
            "pronouns" => "she/her",
            "social" => "@adawhit",
            "on_cam" => true
          },
          %{
            "role" => "Caster",
            "name" => "Bo Ferreira",
            "pronouns" => "he/him",
            "social" => "@bocasts",
            "on_cam" => true
          },
          %{
            "role" => "Caster",
            "name" => "Sam Okoye",
            "pronouns" => "they/them",
            "social" => "@samok",
            "on_cam" => true
          },
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

    {:ok, show} = Broadcasts.set_current_game(show, 4)
    show
  end

  # Game 3 of a series in the top of the first: both lineups, both bullpens,
  # two on and a 1-1 count, so the scorebug, lineups, defense, bullpen and
  # player scenes all have something to draw.
  defp baseball(scope) do
    {:ok, show} =
      Broadcasts.create_show(scope, %{
        "slug" => "demo-baseball",
        "title" => "Harbour Series",
        "sport" => "baseball",
        "stage" => "Game 3",
        "accent_color" => "#22d3ee",
        "talents" => [
          %{
            "role" => "Play-by-play",
            "name" => "Ada Whitlock",
            "pronouns" => "she/her",
            "on_cam" => true
          },
          %{
            "role" => "Analyst",
            "name" => "Bo Ferreira",
            "pronouns" => "he/him",
            "on_cam" => true
          }
        ]
      })

    {:ok, show} =
      Broadcasts.apply_sport_action(show, "save_game_rosters", %{
        "game_rosters" => %{"data" => baseball_rosters()}
      })

    {:ok, show} =
      Broadcasts.apply_sport_action(show, "record_play", %{
        "play" => %{"notation" => "", "result" => "single"}
      })

    {:ok, show} =
      Broadcasts.apply_sport_action(show, "record_play", %{
        "play" => %{"notation" => "", "result" => "double"}
      })

    {:ok, show} = Broadcasts.apply_sport_action(show, "record_pitch", %{"result" => "ball"})
    {:ok, show} = Broadcasts.apply_sport_action(show, "record_pitch", %{"result" => "strike"})
    {:ok, show} = Broadcasts.adjust_score(show, 1, 2)
    show
  end

  defp baseball_rosters do
    """
    AWAY
    TEAM
    Name: Harbour Kings
    Short name: Kings
    Code: HRB
    Logo URL: /images/teams/harbour-kings.svg
    Primary color: #2563eb
    Secondary color: #f8fafc
    Record: 18-8
    LINEUP
    1. Alex Cruz | SS
    2. Morgan Ellis | CF
    3. Sam Okoye | 1B
    4. Riley Park | DH
    5. Jo Lindqvist | 3B
    6. Nico Baptiste | RF
    7. Theo Marsh | C
    8. Ari Kane | LF
    9. Dev Patel | 2B
    STARTING PITCHER
    Jordan Lee
    BULLPEN
    Taylor Reed | Warming
    Casey Moore | Available
    Quinn Hale | Ready
    HOME
    TEAM
    Name: Ridgeline Foxes
    Short name: Foxes
    Code: RDG
    Logo URL: /images/teams/ridgeline-foxes.svg
    Primary color: #e11d48
    Secondary color: #fff7ed
    Record: 16-10
    LINEUP
    1. Jamie Fox | 2B
    2. Drew Hart | C
    3. Kai Moreno | CF
    4. Lee Brandt | 1B
    5. Sol Ortiz | RF
    6. Bo Kim | SS
    7. Max Ruiz | LF
    8. Eli Webb | 3B
    9. Gus Hale | DH
    STARTING PITCHER
    Riley Stone
    BULLPEN
    Avery Cole | Ready
    Pat Lin | Available
    """
  end
end
