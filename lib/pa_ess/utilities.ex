defmodule PaEss.Utilities do
  @moduledoc """
  Some simple helpers for working with the PA/ESS system
  """

  require Logger

  @space "21000"

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

  @spec valid_destination?(PaEss.destination(), Content.Audio.language()) :: boolean()
  def valid_destination?(destination, language) when not is_nil(destination) do
    language == :english or destination in [:chelsea, :south_station]
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

  @doc "Recording of the time from 12:01 to 12:59, given the minutes"
  @spec time_var(integer()) :: String.t()
  def time_var(n) when n > 0 and n < 60 do
    Integer.to_string(9100 + n)
  end

  def countdown_minutes_var(n) when n >= 0 and n < 30 do
    Integer.to_string(5000 + n)
  end

  def countdown_minutes_var(n) when n >= 30 do
    Integer.to_string(5030)
  end

  @doc "Constructs message from TAKE variables"
  @spec take_message([String.t()], Content.Audio.av_type()) :: Content.Audio.canned_message()
  def take_message(vars, av_type) do
    vars_with_spaces = Enum.intersperse(vars, @space)
    {:canned, {take_message_id(vars_with_spaces), vars_with_spaces, av_type}}
  end

  @spec take_message_id([String.t()]) :: String.t()
  def take_message_id(vars) do
    Integer.to_string(102 + length(vars))
  end

  @doc "Take ID for terminal destinations"
  @spec destination_var(PaEss.destination()) :: {:ok, String.t()} | {:error, :unknown}
  def destination_var(:alewife), do: {:ok, "4000"}
  def destination_var(:ashmont), do: {:ok, "4016"}
  def destination_var(:braintree), do: {:ok, "4021"}
  def destination_var(:mattapan), do: {:ok, "4100"}
  def destination_var(:bowdoin), do: {:ok, "4055"}
  def destination_var(:wonderland), do: {:ok, "4044"}
  def destination_var(:oak_grove), do: {:ok, "4022"}
  def destination_var(:forest_hills), do: {:ok, "4043"}
  def destination_var(:lechmere), do: {:ok, "4056"}
  def destination_var(:north_station), do: {:ok, "4027"}
  def destination_var(:government_center), do: {:ok, "4061"}
  def destination_var(:park_street), do: {:ok, "4007"}
  def destination_var(:kenmore), do: {:ok, "4070"}
  def destination_var(:boston_college), do: {:ok, "4202"}
  def destination_var(:cleveland_circle), do: {:ok, "4203"}
  def destination_var(:reservoir), do: {:ok, "4076"}
  def destination_var(:riverside), do: {:ok, "4084"}
  def destination_var(:heath_street), do: {:ok, "4204"}
  def destination_var(:union_square), do: {:ok, "695"}
  def destination_var(:medford_tufts), do: {:ok, "852"}
  def destination_var(_), do: {:error, :unknown}

  @doc """
  Used for parsing headway_direction_name from the source config to a PaEss.destination
  """
  @spec headsign_to_destination(String.t()) :: {:ok, PaEss.destination()} | {:error, :unknown}
  def headsign_to_destination("Alewife"), do: {:ok, :alewife}
  def headsign_to_destination("Ashmont"), do: {:ok, :ashmont}
  def headsign_to_destination("Braintree"), do: {:ok, :braintree}
  def headsign_to_destination("Mattapan"), do: {:ok, :mattapan}
  def headsign_to_destination("Bowdoin"), do: {:ok, :bowdoin}
  def headsign_to_destination("Wonderland"), do: {:ok, :wonderland}
  def headsign_to_destination("Oak Grove"), do: {:ok, :oak_grove}
  def headsign_to_destination("Forest Hills"), do: {:ok, :forest_hills}
  def headsign_to_destination("Chelsea"), do: {:ok, :chelsea}
  def headsign_to_destination("South Station"), do: {:ok, :south_station}
  def headsign_to_destination("Lechmere"), do: {:ok, :lechmere}
  def headsign_to_destination("North Station"), do: {:ok, :north_station}
  def headsign_to_destination("Government Center"), do: {:ok, :government_center}
  def headsign_to_destination("Park Street"), do: {:ok, :park_street}
  def headsign_to_destination("Kenmore"), do: {:ok, :kenmore}
  def headsign_to_destination("Boston College"), do: {:ok, :boston_college}
  def headsign_to_destination("Cleveland Circle"), do: {:ok, :cleveland_circle}
  def headsign_to_destination("Reservoir"), do: {:ok, :reservoir}
  def headsign_to_destination("Riverside"), do: {:ok, :riverside}
  def headsign_to_destination("Heath Street"), do: {:ok, :heath_street}
  def headsign_to_destination("Union Square"), do: {:ok, :union_square}
  def headsign_to_destination("Northbound"), do: {:ok, :northbound}
  def headsign_to_destination("Southbound"), do: {:ok, :southbound}
  def headsign_to_destination("Eastbound"), do: {:ok, :eastbound}
  def headsign_to_destination("Westbound"), do: {:ok, :westbound}
  def headsign_to_destination("Inbound"), do: {:ok, :inbound}
  def headsign_to_destination("Outbound"), do: {:ok, :outbound}
  def headsign_to_destination("Medford/Tufts"), do: {:ok, :medford_tufts}
  def headsign_to_destination(_unknown), do: {:error, :unknown}

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

  @spec destination_to_ad_hoc_string(PaEss.destination()) ::
          {:ok, String.t()} | {:error, :unknown}
  def destination_to_ad_hoc_string(:alewife), do: {:ok, "Alewife"}
  def destination_to_ad_hoc_string(:ashmont), do: {:ok, "Ashmont"}
  def destination_to_ad_hoc_string(:braintree), do: {:ok, "Braintree"}
  def destination_to_ad_hoc_string(:mattapan), do: {:ok, "Mattapan"}
  def destination_to_ad_hoc_string(:bowdoin), do: {:ok, "Bowdoin"}
  def destination_to_ad_hoc_string(:wonderland), do: {:ok, "Wonderland"}
  def destination_to_ad_hoc_string(:oak_grove), do: {:ok, "Oak Grove"}
  def destination_to_ad_hoc_string(:forest_hills), do: {:ok, "Forest Hills"}
  def destination_to_ad_hoc_string(:chelsea), do: {:ok, "Chelsea"}
  def destination_to_ad_hoc_string(:south_station), do: {:ok, "South Station"}
  def destination_to_ad_hoc_string(:lechmere), do: {:ok, "Lechmere"}
  def destination_to_ad_hoc_string(:north_station), do: {:ok, "North Station"}
  def destination_to_ad_hoc_string(:government_center), do: {:ok, "Government Center"}
  def destination_to_ad_hoc_string(:park_street), do: {:ok, "Park Street"}
  def destination_to_ad_hoc_string(:kenmore), do: {:ok, "Kenmore"}
  def destination_to_ad_hoc_string(:boston_college), do: {:ok, "Boston College"}
  def destination_to_ad_hoc_string(:cleveland_circle), do: {:ok, "Cleveland Circle"}
  def destination_to_ad_hoc_string(:reservoir), do: {:ok, "Reservoir"}
  def destination_to_ad_hoc_string(:riverside), do: {:ok, "Riverside"}
  def destination_to_ad_hoc_string(:heath_street), do: {:ok, "Heath Street"}
  def destination_to_ad_hoc_string(:union_square), do: {:ok, "Union Square"}
  def destination_to_ad_hoc_string(:northbound), do: {:ok, "Northbound"}
  def destination_to_ad_hoc_string(:southbound), do: {:ok, "Southbound"}
  def destination_to_ad_hoc_string(:eastbound), do: {:ok, "Eastbound"}
  def destination_to_ad_hoc_string(:westbound), do: {:ok, "Westbound"}
  def destination_to_ad_hoc_string(:inbound), do: {:ok, "Inbound"}
  def destination_to_ad_hoc_string(:outbound), do: {:ok, "Outbound"}
  def destination_to_ad_hoc_string(:medford_tufts), do: {:ok, "Medford/Tufts"}
  def destination_to_ad_hoc_string(_unknown), do: {:error, :unknown}

  @spec route_to_ad_hoc_string(String.t()) :: {:ok, String.t()} | {:error, :unknown}
  def route_to_ad_hoc_string("Red"), do: {:ok, "Red Line"}
  def route_to_ad_hoc_string("Blue"), do: {:ok, "Blue Line"}
  def route_to_ad_hoc_string("Orange"), do: {:ok, "Orange Line"}
  def route_to_ad_hoc_string("Mattapan"), do: {:ok, "Mattapan"}
  def route_to_ad_hoc_string("Green-B"), do: {:ok, "B"}
  def route_to_ad_hoc_string("Green-C"), do: {:ok, "C"}
  def route_to_ad_hoc_string("Green-D"), do: {:ok, "D"}
  def route_to_ad_hoc_string("Green-E"), do: {:ok, "E"}
  def route_to_ad_hoc_string(_unknown), do: {:error, :unknown}

  @spec ad_hoc_trip_description(PaEss.destination(), String.t() | nil) ::
          {:ok, String.t()} | {:error, :unknown}
  def ad_hoc_trip_description(destination, route_id \\ nil)

  def ad_hoc_trip_description(destination, nil)
      when destination in [:eastbound, :westbound, :southbound, :northbound] do
    case destination_to_ad_hoc_string(destination) do
      {:ok, destination_string} ->
        {:ok, "#{destination_string} train"}

      _ ->
        {:error, :unknown}
    end
  end

  def ad_hoc_trip_description(destination, route_id)
      when destination == :eastbound and route_id in ["Green-B", "Green-C", "Green-D", "Green-E"] do
    ad_hoc_trip_description(destination)
  end

  def ad_hoc_trip_description(destination, route_id)
      when destination in [:eastbound, :westbound, :southbound, :northbound] do
    case {destination_to_ad_hoc_string(destination), route_to_ad_hoc_string(route_id)} do
      {{:ok, destination_string}, {:ok, route_string}} ->
        {:ok, "#{destination_string} #{route_string} train"}

      {{:ok, _destination_string}, {:error, :unknown}} ->
        ad_hoc_trip_description(destination)

      _ ->
        {:error, :unknown}
    end
  end

  def ad_hoc_trip_description(destination, nil) do
    case destination_to_ad_hoc_string(destination) do
      {:ok, destination_string} ->
        {:ok, "train to #{destination_string}"}

      _ ->
        {:error, :unknown}
    end
  end

  def ad_hoc_trip_description(destination, route_id)
      when destination in [
             :lechmere,
             :north_station,
             :government_center,
             :park_street,
             :kenmore,
             :union_square,
             :medford_tufts
           ] and
             route_id in ["Green-B", "Green-C", "Green-D", "Green-E"] do
    ad_hoc_trip_description(destination)
  end

  def ad_hoc_trip_description(destination, route_id) do
    case {destination_to_ad_hoc_string(destination), route_to_ad_hoc_string(route_id)} do
      {{:ok, destination_string}, {:ok, route_string}} ->
        {:ok, "#{route_string} train to #{destination_string}"}

      {{:ok, _destination_string}, {:error, :unknown}} ->
        ad_hoc_trip_description(destination)

      _ ->
        {:error, :unknown}
    end
  end

  @spec green_line_branch_var(Content.Utilities.green_line_branch()) :: String.t()
  def green_line_branch_var(:b), do: "536"
  def green_line_branch_var(:c), do: "537"
  def green_line_branch_var(:d), do: "538"
  def green_line_branch_var(:e), do: "539"

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
    {"Sullivan", ["Sullivn", "Sullivan"]},
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
    {"Silver Line Way", ["Slvr Ln Way"]}
  ]

  @spec headsign_abbreviations(String.t()) :: [String.t()]
  def headsign_abbreviations(headsign) do
    Enum.find_value(@headsign_abbreviation_mappings, [], fn {prefix, abbreviations} ->
      if String.starts_with?(headsign, prefix), do: abbreviations
    end)
  end

  @spec prediction_route_name(Predictions.BusPrediction.t()) :: String.t() | nil
  # Don't display "SLW" route name when its outbound headsign already says "Silver Line Way".
  def prediction_route_name(%{route_id: "746", headsign: "Silver Line Way"}), do: nil
  # Heading inbound from Silver Line Way to South Station, all routes take the same path, so
  # treat them as one unit and don't display route names.
  def prediction_route_name(%{stop_id: stop_id, headsign: "South Station"})
      when stop_id in ["74615", "74616"],
      do: nil

  def prediction_route_name(%{route_id: "749"}), do: "SL5"
  def prediction_route_name(%{route_id: "751"}), do: "SL4"
  def prediction_route_name(%{route_id: "743"}), do: "SL3"
  def prediction_route_name(%{route_id: "742"}), do: "SL2"
  def prediction_route_name(%{route_id: "741"}), do: "SL1"
  def prediction_route_name(%{route_id: "77", headsign: "North Cambridge"}), do: "77A"

  def prediction_route_name(%{route_id: "2427", stop_id: "185", headsign: headsign}) do
    cond do
      String.starts_with?(headsign, "Ashmont") -> "27"
      String.starts_with?(headsign, "Wakefield Av") -> "24"
      true -> "2427"
    end
  end

  def prediction_route_name(%{route_id: route_id}), do: route_id
end
