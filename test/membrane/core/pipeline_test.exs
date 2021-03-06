defmodule Membrane.Core.PipelineTest do
  use ExUnit.Case

  alias Membrane.Core.Message
  alias Membrane.Core.Pipeline.{ActionHandler, State}
  alias Membrane.ParentSpec
  alias Membrane.Testing

  require Membrane.Core.Message

  @module Membrane.Core.Pipeline

  defmodule TestPipeline do
    use Membrane.Pipeline

    @impl true
    def handle_init(result) do
      result || {:ok, %{}}
    end

    @impl true
    def handle_notification(notification, child, _ctx, state) do
      {:ok, Map.put(state, :notification, {notification, child})}
    end

    @impl true
    def handle_other(message, _ctx, state) do
      {:ok, Map.put(state, :other, message)}
    end
  end

  defp state(_ctx) do
    [
      state: %State{
        module: TestPipeline,
        internal_state: %{},
        synchronization: %{clock_proxy: nil}
      }
    ]
  end

  setup_all :state

  describe "Handle init" do
    test "should raise an error if handle_init returns an error" do
      assert_raise Membrane.CallbackError, fn ->
        @module.init({TestPipeline, {:error, :reason}})
      end
    end

    test "executes successfully when callback module's handle_init returns {{:ok, spec: spec}}, state} " do
      assert {:ok, state} =
               @module.init({TestPipeline, {{:ok, spec: %Membrane.ParentSpec{}}, %{}}})

      assert %State{internal_state: %{}, module: TestPipeline} = state
    end
  end

  describe "handle_action spec" do
    test "should raise if duplicate elements exist in spec", %{state: state} do
      assert_raise Membrane.ParentError, ~r/.*duplicate.*\[:a\]/i, fn ->
        ActionHandler.handle_action(
          {:spec, %ParentSpec{children: [a: Membrane.Testing.Source, a: Membrane.Testing.Sink]}},
          nil,
          [],
          state
        )
      end
    end

    test "should raise if trying to spawn element with already taken name", %{state: state} do
      state = %State{state | children: %{a: self()}}

      assert_raise Membrane.ParentError, ~r/.*duplicate.*\[:a\]/i, fn ->
        ActionHandler.handle_action(
          {:spec, %ParentSpec{children: [a: Membrane.Testing.Source]}},
          nil,
          [],
          state
        )
      end
    end
  end

  test "notification handling", %{state: state} do
    state = %State{state | children: %{source: %{}}}
    notification = Message.new(:notification, [:source, :abc])
    assert {:noreply, state} = @module.handle_info(notification, state)
    assert %{internal_state: %{notification: {:abc, :source}}} = state

    notification = Message.new(:notification, [:non_existent_child, :abc])

    assert {:stop, {:error, {:unknown_child, :non_existent_child}}, %State{}} =
             @module.handle_info(notification, state)
  end

  test "other messages handling", %{state: state} do
    state = %State{state | children: %{source: %{}}}
    assert {:noreply, state} = @module.handle_info(:other_message, state)
    assert %{internal_state: %{other: :other_message}} = state
  end

  test "Pipeline can be terminated synchronously" do
    {:ok, pid} = Testing.Pipeline.start_link(%Testing.Pipeline.Options{module: TestPipeline})
    assert :ok == Testing.Pipeline.stop_and_terminate(pid, blocking?: true)
  end
end
