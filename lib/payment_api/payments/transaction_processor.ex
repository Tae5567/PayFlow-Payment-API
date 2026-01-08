defmodule PaymentApi.Payments.TransactionProcessor do
  use GenServer
  alias PaymentApi.Payments
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def process_async(transaction_id) do
    GenServer.cast(__MODULE__, {:process, transaction_id})
  end

  @impl true
  def init(_opts) do
    {:ok, %{processing: MapSet.new()}}
  end

  @impl true
  def handle_cast({:process, transaction_id}, state) do
    if MapSet.member?(state.processing, transaction_id) do
      {:noreply, state}
    else
      Task.start(fn -> process_transaction(transaction_id) end)
      {:noreply, %{state | processing: MapSet.put(state.processing, transaction_id)}}
    end
  end

  defp process_transaction(transaction_id) do
    Logger.info("Processing transaction: #{transaction_id}")

    # Simulate payment gateway processing
    Process.sleep(2000)

    case Payments.get_transaction(transaction_id) do
      {:ok, transaction} ->
        new_status = if transaction.fraud_score >= 70, do: "failed", else: "completed"
        Payments.update_transaction_status(transaction, new_status)
        Logger.info("Transaction #{transaction_id} #{new_status}")

      {:error, _} ->
        Logger.error("Transaction #{transaction_id} not found")
    end
  end
end
