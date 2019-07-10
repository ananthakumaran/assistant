defmodule Assistant.Gitlab do
  require Logger

  def merge_merge_request(project_id, id, params) do
    Tesla.put(client(), "/projects/#{project_id}/merge_requests/#{id}/merge", "", query: params)
    |> response
  end

  def rebase_merge_request(project_id, id) do
    Tesla.put(client(), "/projects/#{project_id}/merge_requests/#{id}/rebase", "")
    |> response
  end

  def merge_request(project_id, id, params) do
    Tesla.get(client(), "/projects/#{project_id}/merge_requests/#{id}", query: params)
    |> response
  end

  def merge_requests(project_id, params) do
    Tesla.get(client(), "/projects/#{project_id}/merge_requests", query: params)
    |> response
  end

  def project(full_name) do
    Tesla.get(client(), "/projects/#{URI.encode_www_form(full_name)}")
    |> response
  end

  def response({:ok, %Tesla.Env{body: body, status: status}})
      when status in [200, 202] do
    {:ok, body}
  end

  def response({:ok, %Tesla.Env{body: body, status: status}}) do
    Logger.error("Unexpected response\nstatus: #{status}\nbody: #{inspect(body)}")
    :error
  end

  defp client do
    middlewares = [
      {Tesla.Middleware.BaseUrl, Application.get_env(:assistant, :gitlab_host) <> "/api/v4"},
      {Tesla.Middleware.Headers,
       [{"Private-Token", Application.get_env(:assistant, :private_token)}]},
      Tesla.Middleware.JSON
    ]

    adapter = {Tesla.Adapter.Hackney, [recv_timeout: 30_000]}
    Tesla.client(middlewares, adapter)
  end
end
