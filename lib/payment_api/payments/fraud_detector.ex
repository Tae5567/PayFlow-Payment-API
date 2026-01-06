defmodule PaymentApi.Payments.FraudDetector do
  alias PaymentApi.Payments.Transaction
  alias PaymentApi.Repo
  import Ecto.Query

  @max_transactions_per_hour 10
  @suspicious_amount_threshold Decimal.new(5000)

  def analyze_transaction(attrs) do
    flags = []
    score = 0

    {flags, score} = check_amount(attrs["amount"] || attrs[:amount], flags, score)
    {flags, score} = check_velocity(attrs["customer_email"] || attrs[:customer_email], flags, score)

    %{
      fraud_score: score,
      fraud_flags: flags,
      requires_review: score >= 70
    }
  end

  defp check_amount(nil, flags, score), do: {flags, score}

  defp check_amount(amount, flags, score) when is_binary(amount) do
    check_amount(Decimal.new(amount), flags, score)
  end

  defp check_amount(amount, flags, score) do
    if Decimal.compare(amount, @suspicious_amount_threshold) == :gt do
      {["high_amount" | flags], score + 30}
    else
      {flags, score}
    end
  end

  defp check_velocity(nil, flags, score), do: {flags, score}

  defp check_velocity(email, flags, score) do
    one_hour_ago = DateTime.utc_now() |> DateTime.add(-3600, :second)

    count =
      Transaction
      |> where([t], t.customer_email == ^email)
      |> where([t], t.inserted_at > ^one_hour_ago)
      |> Repo.aggregate(:count)

    if count >= @max_transactions_per_hour do
      {["high_velocity" | flags], score + 40}
    else
      {flags, score}
    end
  end
end
