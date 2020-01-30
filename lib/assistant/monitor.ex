defmodule Assistant.Monitor do
  require Logger
  alias Assistant.Gitlab

  use GenServer

  def start_link(_args \\ []) do
    interval = Application.get_env(:assistant, :poll_interval)
    GenServer.start_link(__MODULE__, interval)
  end

  def init(interval) do
    schedule_sync(5)
    {:ok, interval}
  end

  def handle_info(:sync, interval) do
    :ok = sync()
    schedule_sync(interval)
    {:noreply, interval}
  end

  def handle_info(message, interval) do
    Logger.warn("Unexpected message: #{inspect(message)}")
    {:noreply, interval}
  end

  defp schedule_sync(delay) do
    Logger.debug("Sleeping for #{delay} seconds")
    Process.send_after(self(), :sync, delay * 1000)
  end

  defp sync() do
    fetch_projects()
    |> Enum.each(fn project ->
      :ok = process_open_merge_requests(project)
    end)

    :ok
  end

  defp process_open_merge_requests(project) do
    Logger.info("Fetching merge requests for #{project["name"]}")

    eligible_mrs =
      fetch_eligible_mrs(project)
      |> Enum.shuffle()

    cancel_automerge =
      Enum.find(
        eligible_mrs,
        &match?(
          %{"diverged_commits_count" => diverged_commits, "merge_when_pipeline_succeeds" => true}
          when diverged_commits > 0,
          &1
        )
      )

    waiting_for_pipeline =
      Enum.find(
        eligible_mrs,
        &match?(%{"diverged_commits_count" => 0, "merge_when_pipeline_succeeds" => true}, &1)
      )

    rebase_in_progress =
      Enum.find(
        eligible_mrs,
        &match?(%{"rebase_in_progress" => true}, &1)
      )

    can_merge =
      Enum.find(
        eligible_mrs,
        &match?(%{"diverged_commits_count" => 0, "merge_when_pipeline_succeeds" => false}, &1)
      )

    can_rebase =
      Enum.find(
        eligible_mrs,
        &match?(
          %{
            "diverged_commits_count" => diverged_commits,
            "merge_when_pipeline_succeeds" => false,
            "merge_error" => nil
          }
          when diverged_commits > 0,
          &1
        )
      )

    cond do
      cancel_automerge != nil ->
        mr = cancel_automerge
        Logger.info("Cancelling auto merge: #{mr["title"]}")

        Gitlab.cancel_merge_when_pipeline_succeeds(mr["target_project_id"], mr["iid"])

      waiting_for_pipeline != nil ->
        Logger.info("Waiting for pipeline to finish: #{waiting_for_pipeline["title"]}")

      rebase_in_progress != nil ->
        Logger.info("Waiting for rebase to finish: #{rebase_in_progress["title"]}")

      can_merge != nil ->
        mr = can_merge
        Logger.info("Merging: #{mr["title"]}")

        Gitlab.merge_merge_request(mr["target_project_id"], mr["iid"],
          merge_when_pipeline_succeeds: "true",
          sha: mr["sha"]
        )

      can_rebase != nil ->
        mr = can_rebase
        Logger.info("Rebasing: #{mr["title"]}")
        Gitlab.rebase_merge_request(mr["target_project_id"], mr["iid"])

      true ->
        :ok
    end

    :ok
  end

  defp fetch_eligible_mrs(project) do
    case Gitlab.merge_requests(project["id"], state: "opened", wip: "no", per_page: "100") do
      {:ok, mrs} ->
        Enum.filter(
          mrs,
          &match?(%{"merge_status" => "can_be_merged"}, &1)
        )
        |> Enum.filter(fn mr ->
          # These fields are only available in the lastest version,
          # for older version don't consider them
          Map.get(mr, "blocking_discussions_resolved", true) &&
            !Map.get(mr, "has_conflicts", false)
        end)
        |> Enum.filter(fn mr ->
          Enum.map(mr["labels"], &String.downcase/1)
          |> Enum.member?("reviewed")
        end)
        |> Enum.flat_map(fn mr ->
          case Gitlab.merge_request(mr["target_project_id"], mr["iid"],
                 include_diverged_commits_count: "true",
                 include_rebase_in_progress: "true"
               ) do
            {:ok, mr} ->
              case mr do
                %{"pipeline" => %{"status" => "failed"}} ->
                  []

                %{"head_pipeline" => %{"status" => "failed"}} ->
                  []

                _ ->
                  Logger.debug("Eligible for merge: #{mr["title"]}")

                  [mr]
              end

            :error ->
              []
          end
        end)

      :error ->
        []
    end
  end

  defp fetch_projects() do
    Logger.debug("Fetching projects")

    Application.get_env(:assistant, :projects)
    |> Enum.flat_map(fn full_name ->
      case Gitlab.project(full_name) do
        {:ok, project} ->
          [project]

        :error ->
          Logger.error(
            "Invalid project name #{full_name}. Provide the full project name including namespace."
          )

          []
      end
    end)
  end
end
