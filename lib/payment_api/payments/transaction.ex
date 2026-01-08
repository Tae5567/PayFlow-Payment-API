defmodule PaymentApi.Payments.Transaction do
  use Ecto.Schema
  import Ecto.Changeset


  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @supported_currencies ~w(USD EUR GBP NGN)
  @valid_statuses ~w(pending processing completed failed refunded)
  @valid_payment_methods ~w(card bank_transfer mobile_money)


  schema "transactions" do
    field :amount, :decimal
    field :currency, :string
    field :status, :string, default: "pending"
    field :customer_email, :string
    field :customer_ip, :string
    field :payment_method, :string
    field :description, :string
    field :fraud_score, :integer, default: 0
    field :fraud_flags, {:array, :string}, default: []
    field :metadata, :map, default: %{}
    field :refunded_amount, :decimal, default: Decimal.new("0")
    field :refunded_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :amount,
      :currency,
      :customer_email,
      :customer_ip,
      :payment_method,
      :description,
      :fraud_score,
      :fraud_flags,
      :metadata
    ])
    |> validate_required([:amount, :currency, :status, :customer_email, :payment_method])
    |> validate_inclusion(:currency, @supported_currencies)
    |> validate_inclusion(:payment_method, @valid_payment_methods)
    |> validate_number(:amount, greater_than: 0)
    |> validate_format(:customer_email, ~r/@/)
    |> validate_currency_limits()
  end

  def status_changeset(transaction, status) do
    transaction
    |> cast(%{status: status}, [:status])
    |> validate_inclusion(:status, @valid_statuses)
  end

  def refund_changeset(transaction, amount) do
    transaction
    |> cast(%{refunded_amount: amount, refunded_at: DateTime.utc_now()}, [:refunded_amount, :refunded_at])
    |> validate_refund_amount()
  end

  defp validate_currency_limits(changeset) do
    amount = get_field(changeset, :amount)
    currency = get_field(changeset, :currency)

    if amount && currency do
      max_amount = get_max_amount(currency)
      if Decimal.compare(amount, max_amount) == :gt do
        add_error(changeset, :amount, "exceeds maximum limit for #{currency}")
      else
        changeset
      end
    else
      changeset
    end
  end

  defp validate_refund_amount(changeset) do
    refund_amount = get_field(changeset, :refuned_amount)
    original_amount = get_field(changeset, :amount)

    # Handle nil refund_amount

    cond do
      is_nil(refund_amount) ->
        changeset

      is_nil(original_amount) ->
        changeset

      Decimal.compare(refund_amount, original_amount) == :gt ->
        add_error(changeset, :refunded_amount, "cannot exceed original transaction amount")


      true ->
        changeset
    end
  end

  defp get_max_amount("USD"), do: Decimal.new("10000")
  defp get_max_amount("EUR"), do: Decimal.new("10000")
  defp get_max_amount("GBP"), do: Decimal.new("8000")
  defp get_max_amount("NGN"), do: Decimal.new("150000000")
  defp get_max_amount(_), do: Decimal.new("10000")

end
