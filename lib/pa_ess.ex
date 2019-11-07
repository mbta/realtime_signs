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
  @type audio_id :: {sign_loc_code(), audio_zones()}
  @type destination ::
          :alewife
          | :ashmont
          | :boston_college
          | :bowdoin
          | :braintree
          | :chelsea
          | :cleveland_circle
          | :eastbound
          | :forest_hills
          | :government_center
          | :heath_street
          | :kenmore
          | :lechmere
          | :mattapan
          | :north_station
          | :northbound
          | :oak_grove
          | :park_street
          | :reservoir
          | :riverside
          | :south_station
          | :southbound
          | :westbound
          | :wonderland
end
