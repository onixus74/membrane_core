defmodule Membrane.Support.ChildRemovalTest.Filter do
  @moduledoc """
  Module used in tests for elements removing.

  It allows to:
  * slow down the moment of switching between :prepared and :playing states.
  * send demands and buffers from two input pads to one output pad.

  Should be used along with `Membrane.Support.ChildRemovalTest.Pipeline` as they
  share names (i.e. input_pads: `input1` and `input2`) and exchanged messages' formats.
  """

  use Membrane.Filter

  def_output_pad :output, caps: :any

  def_input_pad :input1, demand_unit: :buffers, caps: :any, availability: :on_request

  def_input_pad :input2, demand_unit: :buffers, caps: :any, availability: :on_request

  def_options demand_generator: [
                type: :function,
                spec: (pos_integer -> non_neg_integer),
                default: &__MODULE__.default_demand_generator/1
              ],
              playing_delay: [type: :integer, default: 0]

  @impl true
  def handle_init(opts) do
    {:ok, Map.put(opts, :pads, MapSet.new())}
  end

  @impl true
  def handle_pad_added(pad, _ctx, state) do
    new_pads = MapSet.put(state.pads, pad)
    {:ok, %{state | pads: new_pads}}
  end

  @impl true
  def handle_pad_removed(pad, _ctx, state) do
    new_pads = MapSet.delete(state.pads, pad)
    {:ok, %{state | pads: new_pads}}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, %{playing_delay: 0} = state) do
    {{:ok, notify: :playing}, state}
  end

  def handle_prepared_to_playing(_ctx, %{playing_delay: time} = state) do
    Process.send_after(self(), :resume_after_wait, time)
    {{:ok, playback_change: :suspend}, state}
  end

  @impl true
  def handle_other(:resume_after_wait, _ctx, state) do
    {{:ok, playback_change: :resume, notify: :playing}, state}
  end

  @impl true
  def handle_demand(:output, size, _unit, _ctx, state) do
    demands =
      state.pads
      |> Enum.map(fn pad -> {:demand, {pad, state.demand_generator.(size)}} end)

    {{:ok, demands}, state}
  end

  @impl true
  def handle_process(_pad, buf, _ctx, state) do
    {{:ok, buffer: {:output, buf}}, state}
  end

  @spec default_demand_generator(integer()) :: integer()
  def default_demand_generator(demand), do: demand
end
