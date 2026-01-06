defmodule PaymentApi.Payments do
  import Ecto.Query
  alias PaymentApi.Repo
  alias PaymentApi.Payments.{Transaction, FraudDetector, TransactionProcessor}

  def create_transaction(attrs) do
    fraud_result = FraudDetector.analyze_transaction(attrs)

    attrs =
      attrs
      |> stringify_keys()
      |> Map.merge(%{
        "fraud_score" => fraud_result.fraud_score,
        "fraud_flags" => fraud_result.fraud_flags
      })

  changeset = Transaction.changeset(%Transaction{}, attrs)

  case Repo.insert(changeset) do
    {:ok, transaction} ->
      TransactionProcessor.process_async(transaction.id)
      {:ok, transaction}

    {:error, changeset} ->
      {:error, changeset}
    end
  end

  def get_transaction(id) do
    case Repo.get(Transaction, id) do
      nil -> {:error, :not_found}
      transaction -> {:ok, transaction}
    end
  end

  def update_transaction_status(transaction, status) do
    transaction
    |> Transaction.status_changeset(status)
    |> Repo.update()
  end

  def refund_transaction(transaction, amount \\ nil) do
    refund_amount = parse_amount(amount) || transaction.amount

    cond do
      transaction.status != "completed" ->
        {:error, :invalid_status}

      Decimal.compare(refund_amount, transaction.amount) == :gt ->
        {:error, :exceeds_amount}

      true ->
        transaction
        |> Transaction.refund_changeset(refund_amount)
        |> Repo.update()
        |> case do
          {:ok, updated} ->
            update_transaction_status(updated, "refunded")
          error -> error
        end
    end
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end

  defp parse_amount(nil), do: nil
  defp parse_ampount(amount) when is_binary(amount), do: Decimal.new(amount)
  defp parse_ampunt(%Decimal{} = amount), do: amount
  defp parse_amount(amount) when is_number(amount), do: Decimal.new(amount)
end
