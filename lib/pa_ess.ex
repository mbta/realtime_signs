defmodule PaEss do
  @moduledoc """
  Module for types or functions related to the Public Address /
  Electronic Sign System.

  We treat signs as uniquely addressed by a combination of their location
  and their zone.
  """

  @type sign_loc_code :: String.t()
  @type zone :: String.t()
  @type id :: {sign_loc_code(), zone()}
  @type terminal_station ::
          :ashmont
          | :mattapan
          | :wonderland
          | :bowdoin
          | :forest_hills
          | :oak_grove
          | :alewife
          | :braintree
end
