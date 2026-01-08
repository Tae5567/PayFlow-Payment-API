defmodule PaymentApi.Payments do
  import Ecto.Query
  alias PaymentApi.Repo
  alias PaymentApi.Payments.{Transaction, FraudDetector, TransactionProcessor}

  def create_transaction(attrs) do
    IO.inspect(attrs, label: "===== ATRRS BEFORE FRAUD CHECK =====")  # DEBUG LINE

    fraud_result = FraudDetector.analyze_transaction(attrs)

    IO.inspect(fraud_result, label: "===== FRAUD RESULT =====")  # DEBUG LINE


    #Convert to strings first
    attrs = stringify_keys(attrs)

    #Then merge fraud data
    attrs_with_fraud = Map.merge(attrs, %{
      "fraud_score" => fraud_result.fraud_score,
      "fraud_flags" => fraud_result.fraud_flags
    })

    IO.inspect(attrs_with_fraud, label: "===== ATRRS AFTER MERGE =====")  # DEBUG LINE

    changeset = Transaction.changeset(%Transaction{}, attrs_with_fraud)

     IO.inspect(changeset, label: "===== CHANGESET CHANGES =====")  # DEBUG LINE

    case Repo.insert(changeset) do
      {:ok, transaction} ->
        IO.puts("======= CALLING PROCESS_ASYNC FOR: #{transaction.id} =======")  # DEBUG LINE
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
  defp parse_amount(amount) when is_binary(amount), do: Decimal.new(amount)
  defp parse_amount(%Decimal{} = amount), do: amount
  defp parse_amount(amount) when is_number(amount), do: Decimal.new(amount)
end
