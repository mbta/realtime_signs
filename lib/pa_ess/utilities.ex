defmodule PaEss.Utilities do
  @moduledoc """
  Some simple helpers for working with the PA/ESS system
  """

  require Logger

  @stopped_regex ~r/Stopped (\d+) stops? away/
  @short_sign_scu_ids ["SCOUSCU001", "GAMOSCU001", "GBABSCU001"]
  @width 24
  @short_width 18

  @doc """
  Used for parsing headway_direction_name from the source config to a PaEss.destination
  """
  @spec headsign_to_destination(String.t()) :: PaEss.destination()
  def headsign_to_destination("Alewife"), do: "place-alfcl"
  def headsign_to_destination("Ashmont"), do: "place-asmnl"
  def headsign_to_destination("Boston College"), do: "place-lake"
  def headsign_to_destination("Bowdoin"), do: "place-bomnl"
  def headsign_to_destination("Braintree"), do: "place-brntn"
  def headsign_to_destination("Chelsea"), do: "place-chels"
  def headsign_to_destination("Eastbound"), do: :eastbound
  def headsign_to_destination("Forest Hills"), do: "place-forhl"
  def headsign_to_destination("Government Center"), do: "place-gover"
  def headsign_to_destination("Heath Street"), do: "place-hsmnl"
  def headsign_to_destination("Inbound"), do: :inbound
  def headsign_to_destination("Mattapan"), do: "place-matt"
  def headsign_to_destination("Medford/Tufts"), do: "place-mdftf"
  def headsign_to_destination("Oak Grove"), do: "place-ogmnl"
  def headsign_to_destination("Outbound"), do: :outbound
  def headsign_to_destination("Riverside"), do: "place-river"
  def headsign_to_destination("South Station"), do: "place-sstat"
  def headsign_to_destination("Southbound"), do: :southbound
  def headsign_to_destination("Union Square"), do: "place-unsqu"
  def headsign_to_destination("Westbound"), do: :westbound
  def headsign_to_destination("Wonderland"), do: "place-wondl"

  @doc """
  Used to translate a PaEss.destination to a string to post to countdown clocks
  """
  @spec destination_to_sign_string(PaEss.destination()) :: String.t()
  def destination_to_sign_string(:eastbound), do: "Eastbound"
  def destination_to_sign_string(:inbound), do: "Inbound"
  def destination_to_sign_string(:northbound), do: "Northbound"
  def destination_to_sign_string(:outbound), do: "Outbound"
  def destination_to_sign_string(:silver_line), do: "SL Outbound"
  def destination_to_sign_string(:southbound), do: "Southbound"
  def destination_to_sign_string(:westbound), do: "Westbound"
  def destination_to_sign_string("place-alfcl"), do: "Alewife"
  def destination_to_sign_string("place-alsgr"), do: "Allston St"
  def destination_to_sign_string("place-amory"), do: "Amory St"
  def destination_to_sign_string("place-andrw"), do: "Andrew"
  def destination_to_sign_string("place-aport"), do: "Airport"
  def destination_to_sign_string("place-aqucl"), do: "Aquarium"
  def destination_to_sign_string("place-armnl"), do: "Arlington"
  def destination_to_sign_string("place-asmnl"), do: "Ashmont"
  def destination_to_sign_string("place-astao"), do: "Assembly"
  def destination_to_sign_string("place-babck"), do: "Babcock St"
  def destination_to_sign_string("place-balsq"), do: "Ball Sq"
  def destination_to_sign_string("place-bbsta"), do: "Back Bay"
  def destination_to_sign_string("place-bckhl"), do: "Back o'Hill"
  def destination_to_sign_string("place-bcnfd"), do: "B'consfield"
  def destination_to_sign_string("place-bcnwa"), do: "Washington"
  def destination_to_sign_string("place-bland"), do: "Blandford"
  def destination_to_sign_string("place-bmmnl"), do: "Beachmont"
  def destination_to_sign_string("place-bndhl"), do: "Brandon Hll"
  def destination_to_sign_string("place-bomnl"), do: "Bowdoin"
  def destination_to_sign_string("place-boyls"), do: "Boylston"
  def destination_to_sign_string("place-brdwy"), do: "Broadway"
  def destination_to_sign_string("place-brico"), do: "Packards Cn"
  def destination_to_sign_string("place-brkhl"), do: "B'kline Hls"
  def destination_to_sign_string("place-brmnl"), do: "Brigham Cir"
  def destination_to_sign_string("place-brntn"), do: "Braintree"
  def destination_to_sign_string("place-bucen"), do: "BU Central"
  def destination_to_sign_string("place-buest"), do: "BU East"
  def destination_to_sign_string("place-butlr"), do: "Butler"
  def destination_to_sign_string("place-bvmnl"), do: "B'kline Vil"
  def destination_to_sign_string("place-capst"), do: "Capen St"
  def destination_to_sign_string("place-ccmnl"), do: "Com College"
  def destination_to_sign_string("place-cedgr"), do: "Cedar Grv"
  def destination_to_sign_string("place-cenav"), do: "Central Ave"
  def destination_to_sign_string("place-chels"), do: "Chelsea"
  def destination_to_sign_string("place-chhil"), do: "Chestnut Hl"
  def destination_to_sign_string("place-chill"), do: "Chestnut Hl"
  def destination_to_sign_string("place-chmnl"), do: "Charles/MGH"
  def destination_to_sign_string("place-chncl"), do: "Chinatown"
  def destination_to_sign_string("place-chswk"), do: "Chiswick Rd"
  def destination_to_sign_string("place-clmnl"), do: "Clvlnd Cir"
  def destination_to_sign_string("place-cntsq"), do: "Central"
  def destination_to_sign_string("place-coecl"), do: "Copley"
  def destination_to_sign_string("place-cool"), do: "Coolidge Cn"
  def destination_to_sign_string("place-davis"), do: "Davis"
  def destination_to_sign_string("place-denrd"), do: "Dean Rd"
  def destination_to_sign_string("place-dwnxg"), do: "Downt'n Xng"
  def destination_to_sign_string("place-eliot"), do: "Eliot"
  def destination_to_sign_string("place-engav"), do: "Englew'd Av"
  def destination_to_sign_string("place-esomr"), do: "E Somervlle"
  def destination_to_sign_string("place-fbkst"), do: "Fairbanks"
  def destination_to_sign_string("place-fenwd"), do: "Fenwood Rd"
  def destination_to_sign_string("place-fenwy"), do: "Fenway"
  def destination_to_sign_string("place-fldcr"), do: "Fields Cnr"
  def destination_to_sign_string("place-forhl"), do: "Frst Hills"
  def destination_to_sign_string("place-gilmn"), do: "Gilman Sq"
  def destination_to_sign_string("place-gover"), do: "Gov't Ctr"
  def destination_to_sign_string("place-grigg"), do: "Griggs St"
  def destination_to_sign_string("place-grnst"), do: "Green St"
  def destination_to_sign_string("place-haecl"), do: "Haymarket"
  def destination_to_sign_string("place-harsq"), do: "Harvard"
  def destination_to_sign_string("place-harvd"), do: "Harvard Ave"
  def destination_to_sign_string("place-hsmnl"), do: "Heath St"
  def destination_to_sign_string("place-hwsst"), do: "Hawes St"
  def destination_to_sign_string("place-hymnl"), do: "Hynes"
  def destination_to_sign_string("place-jaksn"), do: "Jackson Sq"
  def destination_to_sign_string("place-jfk"), do: "JFK/UMass"
  def destination_to_sign_string("place-kencl"), do: "Kenmore"
  def destination_to_sign_string("place-knncl"), do: "Kendall/MIT"
  def destination_to_sign_string("place-kntst"), do: "Kent St"
  def destination_to_sign_string("place-lake"), do: "Boston Coll"
  def destination_to_sign_string("place-lech"), do: "Lechmere"
  def destination_to_sign_string("place-lngmd"), do: "Lngwd Med"
  def destination_to_sign_string("place-longw"), do: "Longwood"
  def destination_to_sign_string("place-masta"), do: "Mass Ave"
  def destination_to_sign_string("place-matt"), do: "Mattapan"
  def destination_to_sign_string("place-mdftf"), do: "Medfd/Tufts"
  def destination_to_sign_string("place-mfa"), do: "MFA"
  def destination_to_sign_string("place-mgngl"), do: "Magoun Sq"
  def destination_to_sign_string("place-miltt"), do: "Milton"
  def destination_to_sign_string("place-mispk"), do: "Mission Pk"
  def destination_to_sign_string("place-mlmnl"), do: "Malden Ctr"
  def destination_to_sign_string("place-mvbcl"), do: "Maverick"
  def destination_to_sign_string("place-newtn"), do: "Newton Hlnd"
  def destination_to_sign_string("place-newto"), do: "Newton Ctr"
  def destination_to_sign_string("place-north"), do: "North Sta"
  def destination_to_sign_string("place-nqncy"), do: "N Quincy"
  def destination_to_sign_string("place-nuniv"), do: "Northeast'n"
  def destination_to_sign_string("place-ogmnl"), do: "Oak Grove"
  def destination_to_sign_string("place-orhte"), do: "Orient Hts"
  def destination_to_sign_string("place-pktrm"), do: "Park St"
  def destination_to_sign_string("place-portr"), do: "Porter"
  def destination_to_sign_string("place-prmnl"), do: "Prudential"
  def destination_to_sign_string("place-qamnl"), do: "Quincy Adms"
  def destination_to_sign_string("place-qnctr"), do: "Quincy Ctr"
  def destination_to_sign_string("place-rbmnl"), do: "Revere Bch"
  def destination_to_sign_string("place-rcmnl"), do: "Roxbury Xng"
  def destination_to_sign_string("place-river"), do: "Riverside"
  def destination_to_sign_string("place-rsmnl"), do: "Reservoir"
  def destination_to_sign_string("place-rugg"), do: "Ruggles"
  def destination_to_sign_string("place-rvrwy"), do: "Riverway"
  def destination_to_sign_string("place-sbmnl"), do: "Stony Brook"
  def destination_to_sign_string("place-sdmnl"), do: "Suffolk Dns"
  def destination_to_sign_string("place-shmnl"), do: "Savin Hill"
  def destination_to_sign_string("place-smary"), do: "St. Mary's"
  def destination_to_sign_string("place-smmnl"), do: "Shawmut"
  def destination_to_sign_string("place-sougr"), do: "South St"
  def destination_to_sign_string("place-spmnl"), do: "Science Pk"
  def destination_to_sign_string("place-sstat"), do: "South Sta"
  def destination_to_sign_string("place-state"), do: "State"
  def destination_to_sign_string("place-sthld"), do: "Sutherland"
  def destination_to_sign_string("place-stpul"), do: "St. Paul St"
  def destination_to_sign_string("place-sull"), do: "Sullivan Sq"
  def destination_to_sign_string("place-sumav"), do: "Summit Ave"
  def destination_to_sign_string("place-symcl"), do: "Symphony"
  def destination_to_sign_string("place-tapst"), do: "Tappan St"
  def destination_to_sign_string("place-tumnl"), do: "Tufts Med"
  def destination_to_sign_string("place-unsqu"), do: "Union Sq"
  def destination_to_sign_string("place-valrd"), do: "Valley Rd"
  def destination_to_sign_string("place-waban"), do: "Waban"
  def destination_to_sign_string("place-wascm"), do: "Washington"
  def destination_to_sign_string("place-welln"), do: "Wellington"
  def destination_to_sign_string("place-wimnl"), do: "Wood Island"
  def destination_to_sign_string("place-wlsta"), do: "Wollaston"
  def destination_to_sign_string("place-wondl"), do: "Wonderland"
  def destination_to_sign_string("place-woodl"), do: "Woodland"
  def destination_to_sign_string("place-wrnst"), do: "Warren St"

  def destination_to_sign_string(destination) do
    Logger.error("Unknown destination: #{inspect(destination)}")
    ""
  end

  @spec destination_to_ad_hoc_string(PaEss.destination()) :: String.t()
  def destination_to_ad_hoc_string(:eastbound), do: "Eastbound"
  def destination_to_ad_hoc_string(:inbound), do: "Inbound"
  def destination_to_ad_hoc_string(:northbound), do: "Northbound"
  def destination_to_ad_hoc_string(:outbound), do: "Outbound"
  def destination_to_ad_hoc_string(:silver_line), do: "Silver Line Outbound"
  def destination_to_ad_hoc_string(:southbound), do: "Southbound"
  def destination_to_ad_hoc_string(:westbound), do: "Westbound"
  def destination_to_ad_hoc_string("place-alfcl"), do: "Alewife"
  def destination_to_ad_hoc_string("place-alsgr"), do: "Allston Street"
  def destination_to_ad_hoc_string("place-amory"), do: "Amory Street"
  def destination_to_ad_hoc_string("place-andrw"), do: "Andrew"
  def destination_to_ad_hoc_string("place-aport"), do: "Airport"
  def destination_to_ad_hoc_string("place-aqucl"), do: "Aquarium"
  def destination_to_ad_hoc_string("place-armnl"), do: "Arlington"
  def destination_to_ad_hoc_string("place-asmnl"), do: "Ashmont"
  def destination_to_ad_hoc_string("place-astao"), do: "Assembly"
  def destination_to_ad_hoc_string("place-babck"), do: "Babcock Street"
  def destination_to_ad_hoc_string("place-balsq"), do: "Ball Square"
  def destination_to_ad_hoc_string("place-bbsta"), do: "Back Bay"
  def destination_to_ad_hoc_string("place-bckhl"), do: "Back of the Hill"
  def destination_to_ad_hoc_string("place-bcnfd"), do: "Beaconsfield"
  def destination_to_ad_hoc_string("place-bcnwa"), do: "Washington Square"
  def destination_to_ad_hoc_string("place-bland"), do: "Blandford Street"
  def destination_to_ad_hoc_string("place-bmmnl"), do: "Beachmont"
  def destination_to_ad_hoc_string("place-bndhl"), do: "Brandon Hall"
  def destination_to_ad_hoc_string("place-bomnl"), do: "Bowdoin"
  def destination_to_ad_hoc_string("place-boyls"), do: "Boylston"
  def destination_to_ad_hoc_string("place-brdwy"), do: "Broadway"
  def destination_to_ad_hoc_string("place-brico"), do: "Packard's Corner"
  def destination_to_ad_hoc_string("place-brkhl"), do: "Brookline Hills"
  def destination_to_ad_hoc_string("place-brmnl"), do: "Brigham Circle"
  def destination_to_ad_hoc_string("place-brntn"), do: "Braintree"
  def destination_to_ad_hoc_string("place-bucen"), do: "Boston University Central"
  def destination_to_ad_hoc_string("place-buest"), do: "Boston University East"
  def destination_to_ad_hoc_string("place-butlr"), do: "Butler"
  def destination_to_ad_hoc_string("place-bvmnl"), do: "Brookline Village"
  def destination_to_ad_hoc_string("place-capst"), do: "Capen Street"
  def destination_to_ad_hoc_string("place-ccmnl"), do: "Community College"
  def destination_to_ad_hoc_string("place-cedgr"), do: "Cedar Grove"
  def destination_to_ad_hoc_string("place-cenav"), do: "Central Avenue"
  def destination_to_ad_hoc_string("place-chels"), do: "Chelsea"
  def destination_to_ad_hoc_string("place-chhil"), do: "Chestnut Hill"
  def destination_to_ad_hoc_string("place-chill"), do: "Chestnut Hill Avenue"
  def destination_to_ad_hoc_string("place-chmnl"), do: "Charles/MGH"
  def destination_to_ad_hoc_string("place-chncl"), do: "Chinatown"
  def destination_to_ad_hoc_string("place-chswk"), do: "Chiswick Road"
  def destination_to_ad_hoc_string("place-clmnl"), do: "Cleveland Circle"
  def destination_to_ad_hoc_string("place-cntsq"), do: "Central"
  def destination_to_ad_hoc_string("place-coecl"), do: "Copley"
  def destination_to_ad_hoc_string("place-cool"), do: "Coolidge Corner"
  def destination_to_ad_hoc_string("place-davis"), do: "Davis"
  def destination_to_ad_hoc_string("place-denrd"), do: "Dean Road"
  def destination_to_ad_hoc_string("place-dwnxg"), do: "Downtown Crossing"
  def destination_to_ad_hoc_string("place-eliot"), do: "Eliot"
  def destination_to_ad_hoc_string("place-engav"), do: "Englewood Avenue"
  def destination_to_ad_hoc_string("place-esomr"), do: "East Somerville"
  def destination_to_ad_hoc_string("place-fbkst"), do: "Fairbanks Street"
  def destination_to_ad_hoc_string("place-fenwd"), do: "Fenwood Road"
  def destination_to_ad_hoc_string("place-fenwy"), do: "Fenway"
  def destination_to_ad_hoc_string("place-fldcr"), do: "Fields Corner"
  def destination_to_ad_hoc_string("place-forhl"), do: "Forest Hills"
  def destination_to_ad_hoc_string("place-gilmn"), do: "Gilman Square"
  def destination_to_ad_hoc_string("place-gover"), do: "Government Center"
  def destination_to_ad_hoc_string("place-grigg"), do: "Griggs Street"
  def destination_to_ad_hoc_string("place-grnst"), do: "Green Street"
  def destination_to_ad_hoc_string("place-haecl"), do: "Haymarket"
  def destination_to_ad_hoc_string("place-harsq"), do: "Harvard"
  def destination_to_ad_hoc_string("place-harvd"), do: "Harvard Avenue"
  def destination_to_ad_hoc_string("place-hsmnl"), do: "Heath Street"
  def destination_to_ad_hoc_string("place-hwsst"), do: "Hawes Street"
  def destination_to_ad_hoc_string("place-hymnl"), do: "Hynes Convention Center"
  def destination_to_ad_hoc_string("place-jaksn"), do: "Jackson Square"
  def destination_to_ad_hoc_string("place-jfk"), do: "JFK/UMass"
  def destination_to_ad_hoc_string("place-kencl"), do: "Kenmore"
  def destination_to_ad_hoc_string("place-knncl"), do: "Kendall/MIT"
  def destination_to_ad_hoc_string("place-kntst"), do: "Kent Street"
  def destination_to_ad_hoc_string("place-lake"), do: "Boston College"
  def destination_to_ad_hoc_string("place-lech"), do: "Lechmere"
  def destination_to_ad_hoc_string("place-lngmd"), do: "Longwood Medical Area"
  def destination_to_ad_hoc_string("place-longw"), do: "Longwood"
  def destination_to_ad_hoc_string("place-masta"), do: "Massachusetts Avenue"
  def destination_to_ad_hoc_string("place-matt"), do: "Mattapan"
  def destination_to_ad_hoc_string("place-mdftf"), do: "Medford/Tufts"
  def destination_to_ad_hoc_string("place-mfa"), do: "Museum of Fine Arts"
  def destination_to_ad_hoc_string("place-mgngl"), do: "Magoun Square"
  def destination_to_ad_hoc_string("place-miltt"), do: "Milton"
  def destination_to_ad_hoc_string("place-mispk"), do: "Mission Park"
  def destination_to_ad_hoc_string("place-mlmnl"), do: "Malden Center"
  def destination_to_ad_hoc_string("place-mvbcl"), do: "Maverick"
  def destination_to_ad_hoc_string("place-newtn"), do: "Newton Highlands"
  def destination_to_ad_hoc_string("place-newto"), do: "Newton Centre"
  def destination_to_ad_hoc_string("place-north"), do: "North Station"
  def destination_to_ad_hoc_string("place-nqncy"), do: "North Quincy"
  def destination_to_ad_hoc_string("place-nuniv"), do: "Northeastern University"
  def destination_to_ad_hoc_string("place-ogmnl"), do: "Oak Grove"
  def destination_to_ad_hoc_string("place-orhte"), do: "Orient Heights"
  def destination_to_ad_hoc_string("place-pktrm"), do: "Park Street"
  def destination_to_ad_hoc_string("place-portr"), do: "Porter"
  def destination_to_ad_hoc_string("place-prmnl"), do: "Prudential"
  def destination_to_ad_hoc_string("place-qamnl"), do: "Quincy Adams"
  def destination_to_ad_hoc_string("place-qnctr"), do: "Quincy Center"
  def destination_to_ad_hoc_string("place-rbmnl"), do: "Revere Beach"
  def destination_to_ad_hoc_string("place-rcmnl"), do: "Roxbury Crossing"
  def destination_to_ad_hoc_string("place-river"), do: "Riverside"
  def destination_to_ad_hoc_string("place-rsmnl"), do: "Reservoir"
  def destination_to_ad_hoc_string("place-rugg"), do: "Ruggles"
  def destination_to_ad_hoc_string("place-rvrwy"), do: "Riverway"
  def destination_to_ad_hoc_string("place-sbmnl"), do: "Stony Brook"
  def destination_to_ad_hoc_string("place-sdmnl"), do: "Suffolk Downs"
  def destination_to_ad_hoc_string("place-shmnl"), do: "Savin Hill"
  def destination_to_ad_hoc_string("place-smary"), do: "Saint Mary's Street"
  def destination_to_ad_hoc_string("place-smmnl"), do: "Shawmut"
  def destination_to_ad_hoc_string("place-sougr"), do: "South Street"
  def destination_to_ad_hoc_string("place-spmnl"), do: "Science Park/West End"
  def destination_to_ad_hoc_string("place-sstat"), do: "South Station"
  def destination_to_ad_hoc_string("place-state"), do: "State"
  def destination_to_ad_hoc_string("place-sthld"), do: "Sutherland Road"
  def destination_to_ad_hoc_string("place-stpul"), do: "Saint Paul Street"
  def destination_to_ad_hoc_string("place-sull"), do: "Sullivan Square"
  def destination_to_ad_hoc_string("place-sumav"), do: "Summit Avenue"
  def destination_to_ad_hoc_string("place-symcl"), do: "Symphony"
  def destination_to_ad_hoc_string("place-tapst"), do: "Tappan Street"
  def destination_to_ad_hoc_string("place-tumnl"), do: "Tufts Medical Center"
  def destination_to_ad_hoc_string("place-unsqu"), do: "Union Square"
  def destination_to_ad_hoc_string("place-valrd"), do: "Valley Road"
  def destination_to_ad_hoc_string("place-waban"), do: "Waban"
  def destination_to_ad_hoc_string("place-wascm"), do: "Washington Street"
  def destination_to_ad_hoc_string("place-welln"), do: "Wellington"
  def destination_to_ad_hoc_string("place-wimnl"), do: "Wood Island"
  def destination_to_ad_hoc_string("place-wlsta"), do: "Wollaston"
  def destination_to_ad_hoc_string("place-wondl"), do: "Wonderland"
  def destination_to_ad_hoc_string("place-woodl"), do: "Woodland"
  def destination_to_ad_hoc_string("place-wrnst"), do: "Warren Street"

  def destination_to_ad_hoc_string(destination) do
    Logger.error("Unknown destination: #{inspect(destination)}")
    ""
  end

  def directional_destination?(destination),
    do: destination in [:eastbound, :westbound, :southbound, :northbound, :inbound, :outbound]

  @spec train_description(PaEss.destination(), String.t() | nil, :audio | :visual) :: String.t()
  def train_description(destination, route_id, av \\ :audio) do
    route_text =
      case route_id do
        "Green-" <> branch -> branch
        _ -> nil
      end

    destination_text =
      case av do
        :audio -> destination_to_ad_hoc_string(destination)
        :visual -> destination_to_sign_string(destination)
      end

    case {route_text, av} do
      {nil, :audio} ->
        "#{destination_text}, train"

      {nil, :visual} ->
        "#{destination_text} train"

      {route_text, :audio} ->
        "#{route_text}, train to, #{destination_text}"

      {route_text, :visual} ->
        "#{route_text} train to #{destination_text}"
    end
  end

  def crowding_text(crowding_description) do
    case crowding_description do
      {:front, _} -> " The front of the train has more space."
      {:back, _} -> " The back of the train has more space."
      {:middle, _} -> " The middle of the train has more space."
      {:front_and_back, _} -> " The front and back of the train have more space."
      {:train_level, :crowded} -> " The train is crowded."
      _ -> ""
    end
  end

  def four_cars_text() do
    " It is a shorter 4-car train. Move toward the front of the train to board, and stand back from the platform edge."
  end

  def four_cars_boarding_text() do
    " It is a shorter 4-car train. You may have to move to a different part of the platform to board."
  end

  @invalid_custom_character ~r/[^a-zA-Z0-9,\/!@': ]/
  @spec validate_custom_string(String.t(), :top | :bottom) :: String.t()
  def validate_custom_string(string, line) do
    string
    |> String.replace(@invalid_custom_character, "")
    |> String.slice(0, if(line == :top, do: 18, else: 24))
  end

  @headsign_abbreviation_mappings [
    {"Ruggles", ["Ruggles"]},
    {"Downtown", ["Downtwn", "Downtown"]},
    {"South Station", ["So Sta", "SouthSta", "South Sta"]},
    {"Harvard", ["Harvard"]},
    {"Ashmont", ["Ashmont"]},
    {"Harbor Point", ["HarbrPt", "HarborPt", "Harbor Pt"]},
    {"Kenmore", ["Kenmore"]},
    {"Broadway", ["Broadwy", "Broadway"]},
    {"Roslindale", ["Roslndl", "Roslndal", "Roslindal"]},
    {"Millennium Park", ["MillnPk", "MillenPk", "Millen Pk"]},
    {"Heath St", ["HeathSt", "Heath St"]},
    {"Kane Square", ["Kane Sq"]},
    {"St Peter's Square", ["StPeter", "StPeteSq", "StPeterSq"]},
    {"Fields Corner", ["FldsCor", "Flds Cor", "FieldsCor"]},
    {"Mattapan", ["Mattapn", "Mattapan"]},
    {"Central", ["Central"]},
    {"Jackson", ["Jackson"]},
    {"Centre St & Eliot St", ["CentrSt", "CentreSt", "Centre St"]},
    {"JFK", ["JFK UMA", "JFKUMass", "JFK/UMass"]},
    {"Forest Hills", ["FrstHls", "Frst Hls", "ForestHls"]},
    {"Franklin Park", ["FrklnPk", "FrnklnPk", "FranklnPk"]},
    {"Arlington Center", ["Arlngtn", "Arlingtn", "Arlington"]},
    {"Clarendon Hill", ["Clarndn", "Clarendn", "Clarendon"]},
    {"Watertown", ["Watertn", "Watertwn", "Watertown"]},
    {"Huron Ave", ["HuronAv", "Huron Av", "Huron Ave"]},
    {"Aberdeen Ave", ["Abrdeen", "Aberdeen", "AbrdeenAv"]},
    {"Waverley", ["Waverly", "Waverley"]},
    {"Belmont", ["Belmont"]},
    {"Arlington Heights", ["Arlngtn", "Arlingtn", "Arlington"]},
    {"North Cambridge", ["N Camb", "NorthCamb"]},
    {"Arlmont", ["Arlmont"]},
    {"Sullivan", ["Sullvn", "Sullivn", "Sullivan"]},
    {"Medford", ["Medford"]},
    {"Wakefield Ave", ["WkfldAv", "WakfldAv", "WakefldAv"]},
    {"Quincy Center", ["Quincy", "QuincyCtr"]},
    {"River St & Milton St", ["MiltnSt", "MiltonSt", "Milton St"]},
    {"Quincy Ctr", ["Quincy", "QuincyCtr"]},
    {"Dudley", ["Dudley"]},
    {"Assembly", ["Asembly", "Assembly"]},
    {"Wellington", ["Welngtn", "Welingtn", "Welington"]},
    {"Back Bay", ["BackBay", "Back Bay"]},
    {"Georgetowne", ["Georgtn", "Georgtwn", "Georgtwne"]},
    {"Cleary Sq", ["Clry Sq", "ClearySq", "Cleary Sq"]},
    {"Reservoir", ["Resrvor", "Resrvoir", "Reservoir"]},
    {"Wren St", ["Wren St"]},
    {"Dedham Line", ["DdmLine", "DedmLine", "DedhmLine"]},
    {"Dedham Sq", ["DedhmSq", "DedhamSq", "Dedham Sq"]},
    {"Legacy Place", ["Legacy", "LegacyPl", "Legacy Pl"]},
    {"Walpole Center", ["WlplCtr", "WalplCtr", "Walpl Ctr"]},
    {"East Walpole", ["E Walpl", "E Walpol", "E Walople"]},
    {"Stimson St", ["StmsnSt", "StimsnSt", "Stimsn St"]},
    {"Dedham Mall", ["DdmMall", "DedmMall", "DedhmMall"]},
    {"Charles River Loop", ["CharlRv", "CharlsRv", "CharlsRiv"]},
    {"Rivermoor", ["Rivmoor", "Rivrmoor", "Rivermoor"]},
    {"VA Hospital", ["VA Hosp", "V A Hosp"]},
    {"Baker & Vermont St", ["BakerSt", "Baker St"]},
    {"Columbian Sq", ["Clmbian", "Colmbian", "Columbian"]},
    {"Montello", ["Mntello", "Montello"]},
    {"South Shore Plaza", ["SoShPlz", "SoShPlza", "SoShPlaza"]},
    {"LaGrange St & Corey St", ["LaGrang", "LaGrange"]},
    {"LaGrange & Corey", ["LaGrang", "LaGrange"]},
    {"Townsend & Humboldt", ["Twnsend", "Townsend", "TownsndSt"]},
    {"Union Sq", ["UnionSq", "Union Sq"]},
    {"Logan Airport", ["Airport"]},
    {"Boston Medical Center", ["Bos Med"]},
    {"Brighton Center", ["Brightn", "Brighton"]},
    {"Louis Pasteur Ave", ["AvPastr", "Av Pastr", "AvPasteur"]},
    {"Ave Louis Pasteur", ["AvPastr", "Av Pastr", "AvPasteur"]},
    {"Avenue Louis Pasteur", ["AvPastr", "Av Pastr", "AvPasteur"]},
    {"Longwood Ave", ["AvPastr", "Av Pastr", "AvPasteur"]},
    {"Nubian", ["Nubian", "NubianSta"]},
    {"Adams & Gallivan", ["Gallivn", "Gallivan"]},
    {"Waltham", ["Waltham"]},
    {"Haymarket", ["Haymrkt", "Haymarkt", "Haymarket"]},
    {"Design Center", ["Design Ctr"]},
    {"Silver Line Way", ["SL Way"]},
    {"Gallivan Blvd", ["Gallivn", "Gallivan"]},
    {"Cobbs Corner Canton", ["Canton"]},
    {"Canton Village", ["Canton"]},
    {"Linden Square", ["Linden", "Linden Sq"]}
  ]

  @spec headsign_abbreviations(String.t() | nil) :: [String.t()]
  def headsign_abbreviations(nil), do: []

  def headsign_abbreviations(headsign) do
    Enum.find_value(@headsign_abbreviation_mappings, [], fn {prefix, abbreviations} ->
      if String.starts_with?(headsign, prefix), do: abbreviations
    end)
  end

  @spec headsign_key(String.t()) :: String.t()
  def headsign_key(headsign) do
    Enum.find_value(@headsign_abbreviation_mappings, headsign, fn {prefix, _} ->
      if String.starts_with?(headsign, prefix), do: prefix
    end)
  end

  @spec prediction_route_name(Predictions.BusPrediction.t()) :: String.t() | nil
  # Don't display route names for SL1, SL2, SL3, or SLW. This also has the effect of combining
  # inbound predictions along the waterfront, where all routes follow the same path.
  def prediction_route_name(%{route_id: route_id})
      when route_id in ["741", "742", "743", "746"],
      do: nil

  # At Nubian platform A, all routes to Ruggles take the same path, so treat them as one unit
  # and don't display route names.
  def prediction_route_name(%{stop_id: "64000", headsign: "Ruggles", route_id: route_id})
      when route_id in ["15", "23", "28", "44", "45"],
      do: nil

  def prediction_route_name(%{route_id: "749"}), do: "SL5"
  def prediction_route_name(%{route_id: "751"}), do: "SL4"
  def prediction_route_name(%{route_id: "77", headsign: "North Cambridge"}), do: "77A"

  def prediction_route_name(%{route_id: "2427", stop_id: "185", headsign: headsign}) do
    cond do
      String.starts_with?(headsign, "Ashmont") -> "27"
      String.starts_with?(headsign, "Wakefield Av") -> "24"
      true -> "2427"
    end
  end

  def prediction_route_name(%{route_id: route_id}), do: route_id

  defp prediction_seconds(prediction, true) do
    prediction.seconds_until_departure
  end

  defp prediction_seconds(prediction, false) do
    prediction.seconds_until_arrival || prediction.seconds_until_departure
  end

  @spec prediction_minutes(Predictions.Prediction.t(), boolean()) ::
          {integer() | :arriving | :boarding, boolean()}
  def prediction_minutes(prediction, terminal?) do
    sec = prediction_seconds(prediction, terminal?)
    min = round(sec / 60)

    cond do
      # The condition on departure seconds < 10 is a temporary stop-gap for an issue where
      # when a train's location status changes to `IN_TRANSIT_TO` but the predictions feed
      # hasn't updated, we may briefly flip back to showing ARR. The stop-gap is intended
      # to make sure we keep showing BRD whenever we are very close to the departure time.
      # Once we have a definitive way of knowing when a train is boarding, we can remove this.
      (prediction.stopped_at_predicted_stop? or prediction.seconds_until_departure < 10) and
          (!terminal? or sec <= 60) ->
        {:boarding, false}

      !terminal? and sec <= 30 ->
        {:arriving, false}

      min > 60 ->
        {60, true}

      prediction.type == :reverse and min > 20 ->
        {div(min, 10) * 10, true}

      true ->
        {max(min, 1), false}
    end
  end

  @spec prediction_approaching?(Predictions.Prediction.t(), boolean()) :: boolean()
  def prediction_approaching?(prediction, terminal?) do
    secs_to_announce = secs_to_announce_approaching(prediction.route_id)

    !terminal? and !prediction.stopped_at_predicted_stop? and
      prediction_seconds(prediction, terminal?) in 0..secs_to_announce
  end

  @spec secs_to_announce_approaching(String.t()) :: integer()
  defp secs_to_announce_approaching("Green-" <> _), do: 30
  defp secs_to_announce_approaching(_other), do: 45

  @spec prediction_stopped?(Predictions.Prediction.t(), boolean()) :: boolean()
  def prediction_stopped?(%{boarding_status: boarding_status} = prediction, terminal?) do
    {_, approximate?} = prediction_minutes(prediction, terminal?)
    !!boarding_status and Regex.match?(@stopped_regex, boarding_status) and !approximate?
  end

  @spec prediction_stops_away(Predictions.Prediction.t()) :: integer()
  def prediction_stops_away(%{boarding_status: status}) do
    [_, str] = Regex.run(@stopped_regex, status)
    String.to_integer(str)
  end

  @spec prediction_four_cars?(Predictions.Prediction.t()) :: boolean()
  def prediction_four_cars?(%Predictions.Prediction{
        route_id: "Red",
        multi_carriage_details: [_, _, _, _]
      }),
      do: true

  def prediction_four_cars?(_), do: false

  def prediction_alewife_braintree?(%Predictions.Prediction{
        stop_id: stop_id
      })
      when stop_id in ["70105", "70061"],
      do: true

  def prediction_alewife_braintree?(_), do: false

  def prediction_ashmont?(%Predictions.Prediction{
        stop_id: "70094"
      }),
      do: true

  def prediction_ashmont?(_), do: false

  @spec tts_sentence([String.t() | nil]) :: String.t()
  def tts_sentence(phrases) do
    Enum.reject(phrases, &is_nil/1)
    |> Enum.join("; ")
    |> then(&"#{&1}.")
  end

  @spec paginate_text(String.t(), integer()) :: Content.Message.pages()
  def paginate_text(text, max_length \\ 24) do
    String.split(text)
    |> Stream.chunk_while(
      nil,
      fn word, acc ->
        if is_nil(acc) do
          {:cont, word}
        else
          new_acc = acc <> " " <> word

          if String.length(new_acc) > max_length do
            {:cont, acc, word}
          else
            {:cont, new_acc}
          end
        end
      end,
      fn
        nil -> {:cont, nil}
        acc -> {:cont, acc, nil}
      end
    )
    |> Stream.chunk_every(2, 2, [""])
    |> Enum.map(fn [top, bottom] -> {top, bottom, 3} end)
  end

  @spec prediction_new_cars?(Predictions.Prediction.t()) :: boolean()
  def prediction_new_cars?(prediction) do
    prediction.route_id == "Red" and !!prediction.multi_carriage_details and
      Enum.any?(prediction.multi_carriage_details, fn carriage ->
        # See http://roster.transithistory.org/ for numbers of new cars
        case Integer.parse(carriage.label) do
          :error -> false
          {n, _remaining} -> n in 1900..2151
        end
      end)
  end

  def sign_length(scu_id) when scu_id in @short_sign_scu_ids, do: :short
  def sign_length(_), do: :long

  def max_text_length(scu_id) when scu_id in @short_sign_scu_ids, do: @short_width
  def max_text_length(_), do: @width
end
