defmodule PaymentApiWeb.TransactionController do
  use PaymentApiWeb, :controller
  alias PaymentApi.Payments

  def create(conn, %{"transaction" => transaction_params}) do
    params = Map.put(transaction_params, "customer_ip", get_client_ip(conn))

    case Payments.create_transaction(params) do
      {:ok, transaction} ->
        conn
        |> put_status(:created)
        |> json(%{data: format_transaction(transaction)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def show(conn, %{"id" => id}) do
    case Payments.get_transaction(id) do
      {:ok, transaction} ->
        json(conn, %{data: format_transaction(transaction)})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Transaction not found"})
    end
  end

  def refund(conn, %{"id" => id} = params) do
    with {:ok, transaction} <- Payments.get_transaction(id),
         {:ok, refunded} <- Payments.refund_transaction(transaction, params["amount"]) do
      json(conn, %{data: format_transaction(refunded)})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Transaction not found"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Refund failed: #{reason}"})
    end
  end

  # Private helper functions

  defp format_transaction(t) do
    %{
      id: t.id,
      amount: Decimal.to_string(t.amount),
      currency: t.currency,
      status: t.status,
      customer_email: t.customer_email,
      payment_method: t.payment_method,
      description: t.description,
      fraud_score: t.fraud_score,
      fraud_flags: t.fraud_flags,
      refunded_amount: Decimal.to_string(t.refunded_amount),
      refunded_at: t.refunded_at,
      created_at: t.inserted_at,
      updated_at: t.updated_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp get_client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip
      [] ->
        conn.remote_ip
        |> :inet_parse.ntoa()
        |> to_string()
    end
  end
end
