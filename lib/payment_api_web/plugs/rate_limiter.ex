defmodule PaymentApiWeb.Plugs.RateLimiter do
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def init(opts), do: opts
  def call(conn, opts) do
    limit = Keyword.get(opts, :limit, 10)
    window = Keyword.get(opts, :window, 60_000)

    key = get_rate_limit_key(conn)

    case Hammer.check_rate("#{key}:#{conn.request_path}", window, limit) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        conn
        |> put_status(:too_many_requests)
        |> json(%{error: "Rate limit exceeded. Try again later."})
        |> halt()
    end
  end

  defp get_rate_limit_key(conn) do
    case get_req_header(conn, "x-api-key") do
      [api_key | _] -> "api_key: #{api_key}"
      [] -> "ip: #{get_ip(conn)}"
    end
  end

  defp get_ip(conn) do
    conn.remote_ip
    |> :inet_parse.ntoa()
    |> to_string()
  end
end
