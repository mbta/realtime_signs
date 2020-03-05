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
          | :braintree
          | :mattapan
          | :bowdoin
          | :wonderland
          | :oak_grove
          | :forest_hills
          | :chelsea
          | :south_station
          | :lechmere
          | :north_station
          | :government_center
          | :park_street
          | :kenmore
          | :boston_college
          | :cleveland_circle
          | :reservoir
          | :riverside
          | :heath_street
          | :northbound
          | :southbound
          | :eastbound
          | :westbound
end
