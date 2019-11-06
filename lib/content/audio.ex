defprotocol Content.Audio do
  @moduledoc """
  Types of audio messages are defined as structs with certain
  variables. The PA system HTTP POSTs take a "mid" (message ID)
  and list of variables. Any "canned" audio announcement we want
  to make should be represented as a struct, which implements
  this protocol, in order to obtain the mid and vars.
  """

  @doc "Converts an audio struct to the mid/vars params for the PA system"
  @spec to_params(Content.Audio.t()) ::
          {:canned, {mid, vars, type}} | {:ad_hoc, {text, type}} | nil
        when mid: String.t(),
             vars: [String.t()],
             type: :audio | :visual | :audio_visual,
             text: String.t()
  def to_params(audio)

  @type destination ::
          :chelsea
          | :south_station
          | :northbound
          | :southbound
          | :eastbound
          | :westbound
          | :alewife
          | :ashmont
          | :braintree
          | :wonderland
          | :bowdoin
          | :forest_hills
          | :oak_grove
          | :park_street
          | :govt_ctr
          | :north_sta
          | :lechmere
          | :riverside
          | :heath_street
          | :boston_college
          | :cleveland_circle
          | :mattapan

  @type language :: :english | :spanish
end
