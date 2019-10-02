defmodule Membrane.Core.Bin.State do
  @moduledoc false
  # Structure representing state of a bin. It is a part of the private API.
  # It does not represent state of bins you construct, it's a state used
  # internally in Membrane.

  alias Membrane.Core.{Parent, Playback, Playbackable, PadModel}
  alias Membrane.Core.Bin.LinkingBuffer
  alias __MODULE__, as: ThisModule
  use Bunch
  use Bunch.Access

  @type t :: %__MODULE__{
          internal_state: Parent.internal_state_t() | nil,
          playback: Playback.t(),
          module: module | nil,
          children: Parent.children_t(),
          pending_pids: MapSet.t(pid),
          terminating?: boolean,
          name: Bin.name_t() | nil,
          bin_options: any | nil,
          pads: PadModel.pads_t() | nil,
          watcher: pid | nil,
          controlling_pid: pid | nil,
          linking_buffer: LinkingBuffer.t(),
          clock_provider: %{
            clock: Clock.t() | nil,
            provider: Element.name_t() | nil, # TODO should this be any child? Probably, eventually yes?
            choice: :auto | :manual
          },
          clock_proxy: Clock.t(),
          handlers: Parent.MessageDispatcher.handlers() | nil,
          synchronization: %{
            timers: %{Timer.id_t() => Timer.t()},
            pipeline_clock: Clock.t(),
            latency: non_neg_integer(),
            stream_sync: Sync.t(),
            clock: Clock.t() | nil
          },
        }

  @enforce_keys [:module, :clock_proxy]
  defstruct @enforce_keys ++
          [
            internal_state: nil,
            playback: %Playback{},
            module: nil,
            children: %{},
            pending_pids: MapSet.new(),
            terminating?: false,
            name: nil,
            bin_options: nil,
            pads: nil,
            watcher: nil,
            controlling_pid: nil,
            linking_buffer: LinkingBuffer.new(),
            clock_provider: %{clock: nil, provider: nil, choice: :auto},
            handlers: nil,
            synchronization: %{}
          ]

  defimpl Playbackable, for: __MODULE__ do
    use Playbackable.Default
    def get_controlling_pid(%ThisModule{controlling_pid: pid}), do: pid
  end
end
