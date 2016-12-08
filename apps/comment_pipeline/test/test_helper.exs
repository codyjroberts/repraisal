alias Experimental.GenStage

defmodule Forwarder do
  @moduledoc """
  A consumer that forwards messages to the given process.
  """

  use GenStage

  def start(init, opts \\ []) do
    GenStage.start(__MODULE__, init, opts)
  end

  def start_link(init, opts \\ []) do
    GenStage.start_link(__MODULE__, init, opts)
  end

  def ask(forwarder, to, n) do
    GenStage.call(forwarder, {:ask, to, n})
  end

  def init(init) do
    init
  end

  def handle_call({:ask, to, n}, _, state) do
    GenStage.ask(to, n)
    {:reply, :ok, [], state}
  end

  def handle_subscribe(any, opts, from, recipient) do
    send recipient, {:consumer_subscribed, from}
    {Keyword.get(opts, :consumer_demand, :automatic), recipient}
  end

  def handle_info(other, recipient) do
    send(recipient, other)
    {:noreply, [], recipient}
  end

  def handle_events(events, _from, recipient) do
    send recipient, {:consumed, events}
    {:noreply, [], recipient}
  end

  def handle_cancel(reason, from, recipient) do
    send recipient, {:consumer_cancelled, from, reason}
    {:noreply, [], recipient}
  end

  def terminate(reason, state) do
    send state, {:terminated, reason}
  end
end

ExUnit.start(exclude: [:skip])
