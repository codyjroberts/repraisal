defmodule CommentPipeline.RepoRequester do
  @moduledoc """
  Supplies a repo name on demand
  """
  alias Experimental.GenStage
  use GenStage

  def start_link() do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc "Sends an event and returns only after the event is dispatched."
  def sync_notify(_pid, event, timeout \\ 5000) do
    GenStage.call(__MODULE__, {:repo, event}, timeout)
  end

  def init(:ok) do
    {:producer, {:queue.new, 0}}
  end

  def handle_call({:repo, event}, from, {queue, pending_demand}) do
    queue = :queue.in({from, event}, queue)
    dispatch_events(queue, pending_demand, [])
  end

  # Called everytime CommentRetriever asks for data
  def handle_demand(incoming_demand, {queue, demand}) do
    dispatch_events(queue, incoming_demand + demand, [])
  end

  defp dispatch_events(queue, 0, events) do
    {:noreply, Enum.reverse(events), {queue, 0}}
  end
  defp dispatch_events(queue, demand, events) do
    case :queue.out(queue) do
      {{:value, {from, event}}, queue} ->
        GenStage.reply(from, :ok)
        dispatch_events(queue, demand - 1, [{from, event} | events])
      {:empty, queue} ->
        {:noreply, Enum.reverse(events), {queue, demand}}
    end
  end
end
