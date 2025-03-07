defmodule PaEss.Utilities do
  @moduledoc """
  Some simple helpers for working with the PA/ESS system
  """

  require Logger

  @space "21000"
  @comma "21012"
  @period "21014"
  @stopped_regex ~r/Stopped (\d+) stops? away/

  @abbreviation_replacements [
    {~r"\bOL\b", "Orange Line"},
    {~r"\bBL\b", "Blue Line"},
    {~r"\bRL\b", "Red Line"},
    {~r"\bGL\b", "Green Line"},
    {~r"\bNB\b", "Northbound"},
    {~r"\bSB\b", "Southbound"},
    {~r"\bEB\b", "Eastbound"},
    {~r"\bWB\b", "Westbound"},
    {~r"\bDesign Ctr\b", "Design Center "},
    {~r"\b88 Blk Flcn\b", "88 Black Falcon Avenue"},
    {~r"\b23 Dry Dock\b", "23 Dry Dock Avenue"},
    {~r"\b21 Dry Dock\b", "21 Dry Dock Avenue"},
    {~r"\bTide St\b", "Tide Street"},
    {~r"\bHarbor St\b", "Harbor Street"},
    {~r"\bSilvr Ln Wy\b", "Silver Line Way"},
    {~r"\bWTC\b", "World Trade Center"},
    {~r"\bHerald St\b", "Herald Street"},
    {~r"\bE Berkeley\b", "East Berkley Street"},
    {~r"\bNewton St\b", "Newton Street"},
    {~r"\bWo'?ster Sq\b", "Worcester Square"},
    {~r"\bMass Ave\b", "Massachusetts Avenue"},
    {~r"\bLenox St\b", "Lenox Street"},
    {~r"\bMelnea Cass\b", "Melnea Cass Boulevard"},
    {~r"\bEastern Ave\b", "Eastern Avenue"},
    {~r"\bBox Dist\b", "Box District"},
    {~r"\bBellingham\b", "Bellingham Square"},
    {~r"\bMedfd/Tufts\b", "Medford Tufts"},
    {~r"\bMedfd/Tufts\b", "Medford/Tufts"},
    {~r"\bBall Sq\b", "Ball Square"},
    {~r"\bMagoun Sq\b", "Magoun Square"},
    {~r"\bGilman Sq\b", "Gilman Square"},
    {~r"\bE Somervlle\b", "East Somerville"},
    {~r"\bUnion Sq\b", "Union Square"},
    {~r"\bScience Pk\b", "Science Park West End"},
    {~r"\bHynes\b", "Hynes Convention Center"},
    {~r"\bNortheast'?n\b", "Northeastern"},
    {~r"\bMFA\b", "Museum of Fine Arts"},
    {~r"\bLngwd Med \b", "Longwood Medical Area"},
    {~r"\bBrigham Cir\b", "Brigham Circle"},
    {~r"\bFenwood Rd\b", "Fenwood Road"},
    {~r"\bMission Pk\b", "Mission Park"},
    {~r"\bBack o'?Hill\b", "Back of the Hill"},
    {~r"\bHeath St\b", "Heath Street"},
    {~r"\bB'?kline Vil\b", "Brookline Village"},
    {~r"\bB'?kline Hls\b", "Brookline Hills"},
    {~r"\bB'?consfield\b", "Beaconsfield"},
    {~r"\bChestnut Hl\b", "Chestnut Hill"},
    {~r"\bNewton Ctr\b", "Newton Centre"},
    {~r"\bNewton Hlnd\b", "Newton Highlands"},
    {~r"\bSt Mary'?s\b", "Saint Mary's Street"},
    {~r"\bHawes St\b", "Hawes Street"},
    {~r"\bKent St\b", "Kent Street"},
    {~r"\bCoolidge Cn\b", "Coolidge Corner"},
    {~r"\bSummit Ave\b", "Summit Avenue"},
    {~r"\bBrandon Hll\b", "Brandon Hall"},
    {~r"\bFairbanks\b", "Fairbanks Street"},
    {~r"\bWashington \b", "Washington Square"},
    {~r"\bTappan St\b", "Tappan Street"},
    {~r"\bDean Rd\b", "Dean Road"},
    {~r"\bEnglew'?d Av\b", "Englewood Avenue"},
    {~r"\bClvlnd Cir\b", "Cleveland Circle"},
    {~r"\bBlandford\b", "Blandford Street"},
    {~r"\bBU East\b", "Boston University East"},
    {~r"\bBU Central\b", "Boston University Central"},
    {~r"\bBU West\b", "Boston University West"},
    {~r"\bSt Paul St\b", "Saint Paul Street"},
    {~r"\bBabcock St\b", "Babcock Street"},
    {~r"\bPackards Cn\b", "Packard's Corner"},
    {~r"\bHarvard Ave\b", "Harvard Avenue"},
    {~r"\bGriggs St\b", "Griggs Street"},
    {~r"\bAllston St\b", "Allston Street"},
    {~r"\bWarren St\b", "Warren Street"},
    {~r"\bWashington \b", "Washington Street"},
    {~r"\bSutherland\b", "Sutherland Road"},
    {~r"\bChiswick Rd\b", "Chiswick Road"},
    {~r"\bChestnut Hl\b", "Chestnut Hill Avenue"},
    {~r"\bSouth St\b", "South Street"},
    {~r"\bBoston Coll\b", "Boston College"},
    {~r"\bSullivan Sq\b", "Sullivan Square"},
    {~r"\bCom College\b", "Community College"},
    {~r"\bMass Ave\b", "Massachusetts Avenue"},
    {~r"\bRoxbury Xng\b", "Roxbury Crossing"},
    {~r"\bJackson Sq\b", "Jackson Square"},
    {~r"\bGreen St\b", "Green Street"},
    {~r"\bFrst Hills\b", "Forest Hills"},
    {~r"\bRevere Bch\b", "Revere Beach"},
    {~r"\bSuffolk Dns\b", "Suffolk Downs"},
    {~r"\bOrient Hts\b", "Orient Heights"},
    {~r"\bKendall/MIT\b", "Kendall MIT"},
    {~r"\bCharles/MGH\b", "Charles MGH"},
    {~r"\bFields Cnr\b", "Fields Corner"},
    {~r"\bCedar Grv\b", "Cedar Grove"},
    {~r"\bCentral Ave\b", "Central Avenue"},
    {~r"\bValley Rd\b", "Valley Road"},
    {~r"\bCapen St\b", "Capen Street"},
    {~r"\bN Quincy\b", "North Quincy"},
    {~r"\bQuincy Adms\b", "Quincy Adams"},
    {~r"\bDownt'?n Xng\b", "Downtown Crossing"},
    {~r"\bSouth Sta\b", "South Station"},
    {~r"\bPark St\b", "Park Street"},
    {~r"\bJFK/Umass\b", "JFK Umass"},
    {~r"\bQuincy Ctr\b", "Quincy Center"},
    {~r"\bTufts Med\b", "Tufts Medical Center"},
    {~r"\bMalden Ctr\b", "Malden Center"},
    {~r"\bNorth Sta\b", "North Station"},
    {~r"\bGov'?t Ctr\b", "Government Center"},
    {~r/\bSVC\b/i, "Service"}
  ]

  @spec valid_range?(integer(), Content.Audio.language()) :: boolean()
  def valid_range?(n, :english) do
    n > 0 and n < 60
  end

  def valid_range?(n, :spanish) do
    n > 0 and n < 21
  end

  @spec number_var(integer(), Content.Audio.language()) :: String.t() | nil
  def number_var(n, :english) do
    if valid_range?(n, :english) do
      Integer.to_string(5500 + n)
    else
      nil
    end
  end

  def number_var(n, :spanish) do
    if valid_range?(n, :spanish) do
      Integer.to_string(37000 + n)
    else
      nil
    end
  end

  @spec generic_number_var(integer()) :: String.t() | nil
  def generic_number_var(n) when n >= 1 and n <= 100, do: Integer.to_string(5000 + n)
  def generic_number_var(_), do: nil

  @doc "Recording of the time from 12:01 to 12:59, given the minutes"
  @spec time_var(integer()) :: String.t()
  def time_var(n) when n > 0 and n < 60 do
    Integer.to_string(9100 + n)
  end

  def countdown_minutes_var(n) when n >= 0 and n <= 100 do
    Integer.to_string(5000 + n)
  end

  @doc "Intersperse spaces in a list of takes, accounting for punctuation"
  @spec pad_takes([String.t()]) :: [String.t()]
  def pad_takes(vars) do
    Enum.chunk_every(vars, 2, 1, [nil])
    |> Enum.flat_map(fn
      [var, next] when next in [nil, @comma, @period] -> [var]
      [var, _] -> [var, @space]
    end)
  end

  @spec take_message_id([String.t()]) :: String.t()
  def take_message_id(vars) do
    # Maps var count to corresponding message id. Since these were added at different times,
    # the message id ranges are not contiguous.
    case length(vars) do
      n when n <= 30 -> 102 + n
      31 -> 220
      n when n <= 45 -> 190 + n
    end
    |> Integer.to_string()
  end

  @doc """
  Used for parsing headway_direction_name from the source config to a PaEss.destination
  """
  @spec headsign_to_destination(String.t()) :: PaEss.destination()
  def headsign_to_destination("Alewife"), do: :alewife
  def headsign_to_destination("Ashmont"), do: :ashmont
  def headsign_to_destination("Braintree"), do: :braintree
  def headsign_to_destination("Mattapan"), do: :mattapan
  def headsign_to_destination("Bowdoin"), do: :bowdoin
  def headsign_to_destination("Wonderland"), do: :wonderland
  def headsign_to_destination("Oak Grove"), do: :oak_grove
  def headsign_to_destination("Forest Hills"), do: :forest_hills
  def headsign_to_destination("Chelsea"), do: :chelsea
  def headsign_to_destination("South Station"), do: :south_station
  def headsign_to_destination("Lechmere"), do: :lechmere
  def headsign_to_destination("North Station"), do: :north_station
  def headsign_to_destination("Government Center"), do: :government_center
  def headsign_to_destination("Park Street"), do: :park_street
  def headsign_to_destination("Kenmore"), do: :kenmore
  def headsign_to_destination("Boston College"), do: :boston_college
  def headsign_to_destination("Cleveland Circle"), do: :cleveland_circle
  def headsign_to_destination("Reservoir"), do: :reservoir
  def headsign_to_destination("Riverside"), do: :riverside
  def headsign_to_destination("Heath Street"), do: :heath_street
  def headsign_to_destination("Union Square"), do: :union_square
  def headsign_to_destination("Northbound"), do: :northbound
  def headsign_to_destination("Southbound"), do: :southbound
  def headsign_to_destination("Eastbound"), do: :eastbound
  def headsign_to_destination("Westbound"), do: :westbound
  def headsign_to_destination("Inbound"), do: :inbound
  def headsign_to_destination("Outbound"), do: :outbound
  def headsign_to_destination("Medford/Tufts"), do: :medford_tufts

  @doc """
  Used to translate a PaEss.destination to a string to post to countdown clocks
  """
  @spec destination_to_sign_string(PaEss.destination()) :: String.t()
  def destination_to_sign_string(:alewife), do: "Alewife"
  def destination_to_sign_string(:ashmont), do: "Ashmont"
  def destination_to_sign_string(:braintree), do: "Braintree"
  def destination_to_sign_string(:mattapan), do: "Mattapan"
  def destination_to_sign_string(:bowdoin), do: "Bowdoin"
  def destination_to_sign_string(:wonderland), do: "Wonderland"
  def destination_to_sign_string(:oak_grove), do: "Oak Grove"
  def destination_to_sign_string(:forest_hills), do: "Frst Hills"
  def destination_to_sign_string(:chelsea), do: "Chelsea"
  def destination_to_sign_string(:south_station), do: "South Sta"
  def destination_to_sign_string(:lechmere), do: "Lechmere"
  def destination_to_sign_string(:north_station), do: "North Sta"
  def destination_to_sign_string(:government_center), do: "Govt Ctr"
  def destination_to_sign_string(:park_street), do: "Park St"
  def destination_to_sign_string(:kenmore), do: "Kenmore"
  def destination_to_sign_string(:boston_college), do: "Boston Col"
  def destination_to_sign_string(:cleveland_circle), do: "Clvlnd Cir"
  def destination_to_sign_string(:reservoir), do: "Reservoir"
  def destination_to_sign_string(:riverside), do: "Riverside"
  def destination_to_sign_string(:heath_street), do: "Heath St"
  def destination_to_sign_string(:union_square), do: "Union Sq"
  def destination_to_sign_string(:northbound), do: "Northbound"
  def destination_to_sign_string(:southbound), do: "Southbound"
  def destination_to_sign_string(:eastbound), do: "Eastbound"
  def destination_to_sign_string(:westbound), do: "Westbound"
  def destination_to_sign_string(:inbound), do: "Inbound"
  def destination_to_sign_string(:outbound), do: "Outbound"
  def destination_to_sign_string(:medford_tufts), do: "Medfd/Tufts"

  @spec destination_to_ad_hoc_string(PaEss.destination()) :: String.t()
  def destination_to_ad_hoc_string(:alewife), do: "Alewife"
  def destination_to_ad_hoc_string(:ashmont), do: "Ashmont"
  def destination_to_ad_hoc_string(:braintree), do: "Braintree"
  def destination_to_ad_hoc_string(:mattapan), do: "Mattapan"
  def destination_to_ad_hoc_string(:bowdoin), do: "Bowdoin"
  def destination_to_ad_hoc_string(:wonderland), do: "Wonderland"
  def destination_to_ad_hoc_string(:oak_grove), do: "Oak Grove"
  def destination_to_ad_hoc_string(:forest_hills), do: "Forest Hills"
  def destination_to_ad_hoc_string(:chelsea), do: "Chelsea"
  def destination_to_ad_hoc_string(:south_station), do: "South Station"
  def destination_to_ad_hoc_string(:lechmere), do: "Lechmere"
  def destination_to_ad_hoc_string(:north_station), do: "North Station"
  def destination_to_ad_hoc_string(:government_center), do: "Government Center"
  def destination_to_ad_hoc_string(:park_street), do: "Park Street"
  def destination_to_ad_hoc_string(:kenmore), do: "Kenmore"
  def destination_to_ad_hoc_string(:boston_college), do: "Boston College"
  def destination_to_ad_hoc_string(:cleveland_circle), do: "Cleveland Circle"
  def destination_to_ad_hoc_string(:reservoir), do: "Reservoir"
  def destination_to_ad_hoc_string(:riverside), do: "Riverside"
  def destination_to_ad_hoc_string(:heath_street), do: "Heath Street"
  def destination_to_ad_hoc_string(:union_square), do: "Union Square"
  def destination_to_ad_hoc_string(:northbound), do: "Northbound"
  def destination_to_ad_hoc_string(:southbound), do: "Southbound"
  def destination_to_ad_hoc_string(:eastbound), do: "Eastbound"
  def destination_to_ad_hoc_string(:westbound), do: "Westbound"
  def destination_to_ad_hoc_string(:inbound), do: "Inbound"
  def destination_to_ad_hoc_string(:outbound), do: "Outbound"
  def destination_to_ad_hoc_string(:medford_tufts), do: "Medford/Tufts"

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

    if route_text do
      "#{route_text} train to #{destination_text}"
    else
      "#{destination_text} train"
    end
  end

  def train_description_tokens(destination, route_id) do
    branch = Content.Utilities.route_branch_letter(route_id)
    if branch, do: [branch, :train_to, destination], else: [destination, :train]
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

  def time_hour_var(hour) when hour >= 0 and hour < 24 do
    adjusted_hour = rem(hour, 12)

    if adjusted_hour == 0,
      do: "8011",
      else: Integer.to_string(7999 + adjusted_hour)
  end

  def time_minutes_var(min)
      when min >= 0 and min < 60 do
    Integer.to_string(9000 + min)
  end

  @spec replace_abbreviations(String.t()) :: String.t()
  def replace_abbreviations(text) when is_binary(text) do
    Enum.reduce(
      @abbreviation_replacements,
      text,
      fn {abbr, replacement}, text ->
        String.replace(text, abbr, replacement)
      end
    )
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
    {"Silver Line Way", ["Slvr Ln Way"]},
    {"Gallivan Blvd", ["Gallivn", "Gallivan"]},
    {"Cobbs Corner Canton", ["Canton"]},
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
      prediction.stopped_at_predicted_stop? and (!terminal? or sec <= 60) -> {:boarding, false}
      !terminal? and sec <= 30 -> {:arriving, false}
      min > 60 -> {60, true}
      prediction.type == :reverse and min > 20 -> {div(min, 10) * 10, true}
      true -> {max(min, 1), false}
    end
  end

  @spec prediction_approaching?(Predictions.Prediction.t(), boolean()) :: boolean()
  def prediction_approaching?(prediction, terminal?) do
    !terminal? and !prediction.stopped_at_predicted_stop? and
      prediction_seconds(prediction, terminal?) in 0..45
  end

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

  @headsign_take_mappings [
    {"Ruggles", "4086"},
    {"Downtown", "563"},
    {"South Station", "4089"},
    {"Harvard", "4003"},
    {"Ashmont", "4016"},
    {"Harbor Point", "564"},
    {"Kenmore", "4201"},
    {"Broadway", "4010"},
    {"Roslindale", "560"},
    {"Millennium Park", "676"},
    {"Heath St", "4204"},
    {"Kane Square", "558"},
    {"St Peter's Square", "572"},
    {"Fields Corner", "4014"},
    {"Mattapan", "4100"},
    {"Central", "4004"},
    {"Jackson", "4040"},
    {"Centre St & Eliot St", "557"},
    {"JFK", "4012"},
    {"Forest Hills", "4043"},
    {"Franklin Park", "559"},
    {"Arlington Center", "613"},
    {"Clarendon Hill", "605"},
    {"Watertown", "606"},
    {"Huron Ave", "607"},
    {"Aberdeen Ave", "804"},
    {"Waverley", "608"},
    {"Belmont", "609"},
    {"Arlington Heights", "610"},
    {"North Cambridge", "611"},
    {"Arlmont", "612"},
    {"Sullivan", "4025"},
    {"Medford", "614"},
    {"Wakefield Ave", "621"},
    {"Quincy Center", "620"},
    {"River St & Milton St", "619"},
    {"Quincy Ctr", "620"},
    {"Dudley", "632"},
    {"Assembly", "4209"},
    {"Wellington", "4024"},
    {"Back Bay", "4036"},
    {"Georgetowne", "674"},
    {"Cleary Sq", "670"},
    {"Reservoir", "4076"},
    {"Wren St", "698"},
    {"Dedham Line", "671"},
    {"Dedham Sq", "847"},
    {"Legacy Place", "848"},
    {"Walpole Center", "697"},
    {"East Walpole", "673"},
    {"Stimson St", "693"},
    {"Dedham Mall", "672"},
    {"Charles River Loop", "669"},
    {"Rivermoor", "677"},
    {"VA Hospital", "696"},
    {"Baker & Vermont St", "668"},
    {"Columbian Sq", "805"},
    {"Montello", "806"},
    {"South Shore Plaza", "808"},
    {"LaGrange St & Corey St", "675"},
    {"LaGrange & Corey", "675"},
    {"Townsend & Humboldt", "694"},
    {"Union Sq", "695"},
    {"Logan Airport", "562"},
    {"Boston Medical Center", "568"},
    {"Brighton Center", "566"},
    {"Louis Pasteur Ave", "567"},
    {"Ave Louis Pasteur", "567"},
    {"Avenue Louis Pasteur", "567"},
    {"Longwood Ave", "567"},
    {"Nubian", "812"},
    {"Adams & Gallivan", "569"},
    {"Waltham", "561"},
    {"Haymarket", "4028"},
    {"Silver Line Way", "570"},
    {"Drydock", "571"},
    {"Chelsea", "860"},
    {"Gallivan Blvd", "881"},
    {"Brookline Ave", "885"},
    {"Brookline Village", "886"},
    {"Cobbs Corner Canton", "887"},
    {"Linden Sq", "889"}
  ]

  @spec audio_take(term()) :: String.t() | nil
  def audio_take(:alewife), do: "4000"
  def audio_take(:alewife_), do: "892"
  def audio_take(:ashmont), do: "4016"
  def audio_take(:ashmont_), do: "895"
  def audio_take(:braintree), do: "4021"
  def audio_take(:braintree_), do: "902"
  def audio_take(:mattapan), do: "4100"
  def audio_take(:mattapan_), do: "913"
  def audio_take(:bowdoin), do: "4055"
  def audio_take(:bowdoin_), do: "900"
  def audio_take(:wonderland), do: "4044"
  def audio_take(:wonderland_), do: "921"
  def audio_take(:oak_grove), do: "4022"
  def audio_take(:oak_grove_), do: "915"
  def audio_take(:forest_hills), do: "4043"
  def audio_take(:forest_hills_), do: "907"
  def audio_take(:chelsea), do: "860"
  def audio_take(:south_station), do: "4089"
  def audio_take(:lechmere), do: "4056"
  def audio_take(:lechmere_), do: "912"
  def audio_take(:north_station), do: "4027"
  def audio_take(:north_station_), do: "914"
  def audio_take(:government_center), do: "4061"
  def audio_take(:government_center_), do: "908"
  def audio_take(:park_street), do: "4007"
  def audio_take(:park_street_), do: "916"
  def audio_take(:kenmore), do: "4070"
  def audio_take(:kenmore_), do: "911"
  def audio_take(:boston_college), do: "4202"
  def audio_take(:boston_college_), do: "899"
  def audio_take(:cleveland_circle), do: "4203"
  def audio_take(:cleveland_circle_), do: "904"
  def audio_take(:reservoir), do: "4076"
  def audio_take(:reservoir_), do: "917"
  def audio_take(:riverside), do: "4084"
  def audio_take(:riverside_), do: "918"
  def audio_take(:heath_street), do: "4204"
  def audio_take(:heath_street_), do: "909"
  def audio_take(:union_square), do: "695"
  def audio_take(:medford_tufts), do: "852"
  def audio_take(:southbound), do: "787"
  def audio_take(:northbound), do: "788"
  def audio_take(:eastbound), do: "867"
  def audio_take(:westbound), do: "868"
  def audio_take(:inbound), do: "33003"
  def audio_take(:outbound), do: "33004"
  def audio_take(:the_next_bus_to), do: "543"
  def audio_take(:the_following_bus_to), do: "858"
  def audio_take(:the_next), do: "501"
  def audio_take(:the_following), do: "667"
  def audio_take(:train), do: "864"
  def audio_take(:train_), do: "920"
  def audio_take(:bus_to), do: "859"
  def audio_take(:train_to), do: "507"
  def audio_take(:train_to_), do: "919"
  def audio_take(:departs), do: "502"
  def audio_take(:arrives), do: "503"
  def audio_take(:track_change), do: "540"
  def audio_take(:is_now_boarding), do: "544"
  def audio_take(:in), do: "504"
  def audio_take(:is), do: "533"
  def audio_take(:stopped), do: "641"
  def audio_take(:stop_away), do: "535"
  def audio_take(:stops_away), do: "534"
  def audio_take(:the_first), do: "866"
  def audio_take(:scheduled_to_arrive_at), do: "865"
  def audio_take(:upcoming_departures), do: "548"
  def audio_take(:upcoming_arrivals), do: "550"
  def audio_take(:is_now_arriving), do: "24055"
  def audio_take(:upper_level_departures), do: "616"
  def audio_take(:lower_level_departures), do: "617"
  def audio_take(:board_routes_71_and_73_on_upper_level), do: "618"
  def audio_take(:will_announce_platform_soon), do: "849"
  def audio_take(:will_announce_platform_later), do: "857"
  def audio_take(:departing), do: "530"
  def audio_take(:arriving), do: "531"
  def audio_take(:on_track_1), do: "541"
  def audio_take(:on_track_2), do: "542"
  def audio_take(:on_the), do: "851"
  def audio_take(:platform), do: "529"
  def audio_take(:on_the_ashmont_platform), do: "894"
  def audio_take(:on_the_braintree_platform), do: "901"
  def audio_take(:_), do: "21000"
  def audio_take(:","), do: "21012"
  def audio_take(:.), do: "21014"
  def audio_take(:minute), do: "532"
  def audio_take(:minutes), do: "505"
  def audio_take(:no_service), do: "879"
  def audio_take(:there_is_no), do: "880"
  def audio_take(:there_is_no_), do: "861"
  def audio_take(:bus_service_to), do: "877"
  def audio_take(:no_bus_service), do: "878"
  def audio_take(:service_at_this_station), do: "863"
  def audio_take(:service_ended), do: "882"
  def audio_take(:platform_closed), do: "884"
  def audio_take(:boarding_button_message), do: "869"
  # audio: "Attention passengers, the next", visual: ""
  def audio_take(:attention_passengers_the_next), do: "896"
  # audio: "Attention passengers, the next", visual: "Shorter 4 car"
  def audio_take(:shorter_4_car), do: "923"
  def audio_take(:is_now_approaching), do: "910"
  # audio: "is now approaching", visual: "now approaching"
  def audio_take(:now_approaching), do: "924"
  def audio_take(:with_all_new_red_line_cars), do: "893"

  # audio: "It is a shorter 4-car train. Move toward the front of the train to board, and stand back from the platform edge.", visual: "Please move to front of the train to board."
  def audio_take(:four_car_train_message), do: "922"
  # "Please stand back from the platform edge."
  def audio_take(:stand_back_message), do: "925"
  def audio_take(:b), do: "536"
  def audio_take(:b_), do: "897"
  def audio_take(:c), do: "537"
  def audio_take(:c_), do: "903"
  def audio_take(:d), do: "538"
  def audio_take(:d_), do: "905"
  def audio_take(:e), do: "539"
  def audio_take(:e_), do: "906"

  def audio_take({:minutes, minutes}) do
    number_var(minutes, :english) || generic_number_var(minutes)
  end

  def audio_take({:number, number}) do
    generic_number_var(number)
  end

  def audio_take({:headsign, nil}), do: nil

  def audio_take({:headsign, headsign}) do
    Enum.find_value(@headsign_take_mappings, fn {prefix, take} ->
      if String.starts_with?(headsign, prefix), do: take
    end)
  end

  def audio_take({:hour, hour}), do: time_hour_var(hour)
  def audio_take({:minute, minute}), do: time_minutes_var(minute)

  def audio_take({:route, "SL5"}), do: "587"
  def audio_take({:route, "SL4"}), do: "586"
  def audio_take({:route, "1"}), do: "573"
  def audio_take({:route, "8"}), do: "574"
  def audio_take({:route, "14"}), do: "575"
  def audio_take({:route, "15"}), do: "576"
  def audio_take({:route, "19"}), do: "577"
  def audio_take({:route, "23"}), do: "578"
  def audio_take({:route, "24"}), do: "622"
  def audio_take({:route, "27"}), do: "623"
  def audio_take({:route, "2427"}), do: "629"
  def audio_take({:route, "28"}), do: "579"
  def audio_take({:route, "29"}), do: "624"
  def audio_take({:route, "30"}), do: "625"
  def audio_take({:route, "31"}), do: "626"
  def audio_take({:route, "33"}), do: "627"
  def audio_take({:route, "34"}), do: "678"
  def audio_take({:route, "34E"}), do: "679"
  def audio_take({:route, "35"}), do: "680"
  def audio_take({:route, "36"}), do: "681"
  def audio_take({:route, "37"}), do: "682"
  def audio_take({:route, "38"}), do: "683"
  def audio_take({:route, "39"}), do: "684"
  def audio_take({:route, "40"}), do: "685"
  def audio_take({:route, "41"}), do: "580"
  def audio_take({:route, "42"}), do: "581"
  def audio_take({:route, "44"}), do: "582"
  def audio_take({:route, "45"}), do: "583"
  def audio_take({:route, "47"}), do: "584"
  def audio_take({:route, "50"}), do: "686"
  def audio_take({:route, "51"}), do: "687"
  def audio_take({:route, "66"}), do: "585"
  def audio_take({:route, "69"}), do: "590"
  def audio_take({:route, "71"}), do: "591"
  def audio_take({:route, "72"}), do: "592"
  def audio_take({:route, "73"}), do: "594"
  def audio_take({:route, "74"}), do: "595"
  def audio_take({:route, "75"}), do: "596"
  def audio_take({:route, "77"}), do: "597"
  def audio_take({:route, "77A"}), do: "598"
  def audio_take({:route, "78"}), do: "599"
  def audio_take({:route, "80"}), do: "600"
  def audio_take({:route, "86"}), do: "601"
  def audio_take({:route, "87"}), do: "602"
  def audio_take({:route, "88"}), do: "603"
  def audio_take({:route, "89"}), do: "688"
  def audio_take({:route, "90"}), do: "689"
  def audio_take({:route, "94"}), do: "690"
  def audio_take({:route, "96"}), do: "604"
  def audio_take({:route, "109"}), do: "890"
  def audio_take({:route, "170"}), do: "588"
  def audio_take({:route, "171"}), do: "589"
  def audio_take({:route, "226"}), do: "809"
  def audio_take({:route, "230"}), do: "810"
  def audio_take({:route, "236"}), do: "811"
  def audio_take({:route, "245"}), do: "628"
  def audio_take({:route, "716"}), do: "888"

  def audio_take({:boarding, "Green-B", "70197", :boston_college}), do: "813"
  def audio_take({:boarding, "Green-B", "70197", :kenmore}), do: "820"
  def audio_take({:boarding, "Green-C", "70196", :cleveland_circle}), do: "814"
  def audio_take({:boarding, "Green-C", "70196", :kenmore}), do: "823"
  def audio_take({:boarding, "Green-D", "70199", :reservoir}), do: "815"
  def audio_take({:boarding, "Green-D", "70199", :riverside}), do: "818"
  def audio_take({:boarding, "Green-D", "70199", :kenmore}), do: "822"
  def audio_take({:boarding, "Green-E", "70198", :heath_street}), do: "816"
  def audio_take({:boarding, "Green-E", "70198", :kenmore}), do: "821"

  def audio_take({:crowding, {:front, _}}), do: "870"
  def audio_take({:crowding, {:back, _}}), do: "871"
  def audio_take({:crowding, {:middle, _}}), do: "872"
  def audio_take({:crowding, {:front_and_back, _}}), do: "873"
  def audio_take({:crowding, {:train_level, :crowded}}), do: "876"
  def audio_take({:crowding, _}), do: "21000"

  def audio_take({:line, "Red"}), do: "3005"
  def audio_take({:line, "Orange"}), do: "3006"
  def audio_take({:line, "Blue"}), do: "3007"
  def audio_take({:line, "Green"}), do: "3008"
  def audio_take({:line, "Mattapan"}), do: "3009"
  def audio_take({:line, _}), do: audio_take(:train)

  def audio_take({:passthrough, :alewife, _}), do: "32114"
  def audio_take({:passthrough, :southbound, "Red"}), do: "891"
  def audio_take({:passthrough, :bowdoin, _}), do: "32111"
  def audio_take({:passthrough, :wonderland, _}), do: "32110"
  def audio_take({:passthrough, :forest_hills, _}), do: "32113"
  def audio_take({:passthrough, :oak_grove, _}), do: "32112"

  def audio_take(_), do: nil

  @spec audio_message([term()]) :: Content.Audio.canned_message()
  def audio_message(items, av \\ :audio) do
    vars =
      Enum.map(items, fn item ->
        case audio_take(item) do
          nil ->
            Logger.error("No audio for: #{inspect(item)}")
            audio_take(:_)

          take ->
            take
        end
      end)
      |> pad_takes()

    {:canned, {take_message_id(vars), vars, av}}
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
end
