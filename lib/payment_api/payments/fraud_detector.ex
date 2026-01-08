
defmodule PaymentApi.Payments.FraudDetector do
  alias PaymentApi.Payments.Transaction
  alias PaymentApi.Repo
  import Ecto.Query

  @max_transactions_per_hour 10
  @suspicious_amount_threshold Decimal.new(5000)

  def analyze_transaction(attrs) do
    flags = []
    score = 0

    # Get amount from either string key or atom key
    amount = get_amount(attrs)
    email = attrs["customer_email"] || attrs[:customer_email]


    #DEBUG
    IO.inspect(attrs, label: "FRAUD CHECK ATTRS")
    IO.inspect(amount, label: "FRAUD CHECK AMOUNT")
    IO.inspect(@suspicious_amount_threshold, label: "THRESHOLD")

    {flags, score} = check_amount(amount, flags, score)
    {flags, score} = check_velocity(email, flags, score)

    IO.inspect({flags, score}, label: "FRAUD CHECK RESULT")

    %{
      fraud_score: score,
      fraud_flags: flags,
      requires_review: score >= 70
    }
  end

  # Helper to extract and convert amount
  defp get_amount(attrs) do
    case attrs["amount"] || attrs[:amount] do
      nil -> nil
      amount when is_binary(amount) -> Decimal.new(amount)
      %Decimal{} = amount -> amount
      amount when is_number(amount) -> Decimal.new(amount)
    end
  end

  defp check_amount(nil, flags, score), do: {flags, score}

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
