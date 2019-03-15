defmodule PaEss do
  @moduledoc """
  Module for types or functions related to the Public Address /
  Electronic Sign System.

  We treat signs as uniquely addressed by a combination of their location
  and their zone.
  """

  @type sign_loc_code :: String.t()
  @type text_zone :: String.t()
  @type audio_zones :: [String.t()]
  @type text_id :: {sign_loc_code(), text_zone()}
  @type audio_id :: {text_zone(), audio_zones()}
  @type terminal_station ::
          :ashmont
          | :mattapan
          | :wonderland
          | :bowdoin
          | :forest_hills
          | :oak_grove
          | :alewife
          | :braintree
          | :boston_college
          | :cleveland_circle
          | :riverside
          | :heath_st
          | :reservoir
          | :lechmere
          | :north_station
          | :government_center
          | :park_st
          | :kenmore
end
