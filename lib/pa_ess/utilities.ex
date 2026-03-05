defmodule PaEss.Utilities do
  @moduledoc """
  Some simple helpers for working with the PA/ESS system
  """

  require Logger

  @space "21000"
  @comma "21012"
  @period "21014"
  @stopped_regex ~r/Stopped (\d+) stops? away/
  @short_sign_scu_ids ["SCOUSCU001"]
  @width 24
  @short_width 18

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
    {~r/\bSVC\b/i, "Service"},
    {~r/\bCol\b/i, "College"}
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
  def headsign_to_destination("Alewife"), do: :"place-alfcl"
  def headsign_to_destination("Ashmont"), do: :"place-asmnl"
  def headsign_to_destination("Boston College"), do: :"place-lake"
  def headsign_to_destination("Bowdoin"), do: :"place-bomnl"
  def headsign_to_destination("Braintree"), do: :"place-brntn"
  def headsign_to_destination("Chelsea"), do: :"place-chels"
  def headsign_to_destination("Eastbound"), do: :eastbound
  def headsign_to_destination("Forest Hills"), do: :"place-forhl"
  def headsign_to_destination("Government Center"), do: :"place-gover"
  def headsign_to_destination("Heath Street"), do: :"place-hsmnl"
  def headsign_to_destination("Inbound"), do: :inbound
  def headsign_to_destination("Mattapan"), do: :"place-matt"
  def headsign_to_destination("Medford/Tufts"), do: :"place-mdftf"
  def headsign_to_destination("Oak Grove"), do: :"place-ogmnl"
  def headsign_to_destination("Outbound"), do: :outbound
  def headsign_to_destination("Riverside"), do: :"place-river"
  def headsign_to_destination("South Station"), do: :"place-sstat"
  def headsign_to_destination("Southbound"), do: :southbound
  def headsign_to_destination("Union Square"), do: :"place-unsqu"
  def headsign_to_destination("Westbound"), do: :westbound
  def headsign_to_destination("Wonderland"), do: :"place-wondl"

  @doc """
  Used to translate a PaEss.destination to a string to post to countdown clocks
  """
  @spec destination_to_sign_string(PaEss.destination()) :: String.t()
  def destination_to_sign_string(:eastboound), do: "Eastbound"
  def destination_to_sign_string(:inbound), do: "Inbound"
  def destination_to_sign_string(:northbound), do: "Northbound"
  def destination_to_sign_string(:outbound), do: "Outbound"
  def destination_to_sign_string(:"place-alfcl"), do: "Alewife"
  def destination_to_sign_string(:"place-alsgr"), do: "Allston St"
  def destination_to_sign_string(:"place-amory"), do: "Amory St"
  def destination_to_sign_string(:"place-andrw"), do: "Andrew"
  def destination_to_sign_string(:"place-aport"), do: "Airport"
  def destination_to_sign_string(:"place-aqucl"), do: "Aquarium"
  def destination_to_sign_string(:"place-armnl"), do: "Arlington"
  def destination_to_sign_string(:"place-asmnl"), do: "Ashmont"
  def destination_to_sign_string(:"place-astao"), do: "Assembly"
  def destination_to_sign_string(:"place-babck"), do: "Babcock St"
  def destination_to_sign_string(:"place-balsq"), do: "Ball Sq"
  def destination_to_sign_string(:"place-bbsta"), do: "Back Bay"
  def destination_to_sign_string(:"place-bckhl"), do: "Back o'Hill"
  def destination_to_sign_string(:"place-bcnfd"), do: "B'consfield"
  def destination_to_sign_string(:"place-bcnwa"), do: "Washington"
  def destination_to_sign_string(:"place-bland"), do: "Blandford"
  def destination_to_sign_string(:"place-bmmnl"), do: "Beachmont"
  def destination_to_sign_string(:"place-bndhl"), do: "Brandon Hll"
  def destination_to_sign_string(:"place-bomnl"), do: "Bowdoin"
  def destination_to_sign_string(:"place-boyls"), do: "Boylston"
  def destination_to_sign_string(:"place-brdwy"), do: "Broadway"
  def destination_to_sign_string(:"place-brico"), do: "Packards Cn"
  def destination_to_sign_string(:"place-brkhl"), do: "B'kline Hls"
  def destination_to_sign_string(:"place-brmnl"), do: "Brigham Cir"
  def destination_to_sign_string(:"place-brntn"), do: "Braintree"
  def destination_to_sign_string(:"place-bucen"), do: "BU Central"
  def destination_to_sign_string(:"place-buest"), do: "BU East"
  def destination_to_sign_string(:"place-butlr"), do: "Butler"
  def destination_to_sign_string(:"place-bvmnl"), do: "B'kline Vil"
  def destination_to_sign_string(:"place-capst"), do: "Capen St"
  def destination_to_sign_string(:"place-ccmnl"), do: "Com College"
  def destination_to_sign_string(:"place-cedgr"), do: "Cedar Grv"
  def destination_to_sign_string(:"place-cenav"), do: "Central Ave"
  def destination_to_sign_string(:"place-chels"), do: "Chelsea"
  def destination_to_sign_string(:"place-chhil"), do: "Chestnut Hl"
  def destination_to_sign_string(:"place-chill"), do: "Chestnut Hl"
  def destination_to_sign_string(:"place-chmnl"), do: "Charles/MGH"
  def destination_to_sign_string(:"place-chncl"), do: "Chinatown"
  def destination_to_sign_string(:"place-chswk"), do: "Chiswick Rd"
  def destination_to_sign_string(:"place-clmnl"), do: "Clvlnd Cir"
  def destination_to_sign_string(:"place-cntsq"), do: "Central"
  def destination_to_sign_string(:"place-coecl"), do: "Copley"
  def destination_to_sign_string(:"place-cool"), do: "Coolidge Cn"
  def destination_to_sign_string(:"place-davis"), do: "Davis"
  def destination_to_sign_string(:"place-denrd"), do: "Dean Rd"
  def destination_to_sign_string(:"place-dwnxg"), do: "Downt'n Xng"
  def destination_to_sign_string(:"place-eliot"), do: "Eliot"
  def destination_to_sign_string(:"place-engav"), do: "Englew'd Av"
  def destination_to_sign_string(:"place-esomr"), do: "E Somervlle"
  def destination_to_sign_string(:"place-fbkst"), do: "Fairbanks"
  def destination_to_sign_string(:"place-fenwd"), do: "Fenwood Rd"
  def destination_to_sign_string(:"place-fenwy"), do: "Fenway"
  def destination_to_sign_string(:"place-fldcr"), do: "Fields Cnr"
  def destination_to_sign_string(:"place-forhl"), do: "Frst Hills"
  def destination_to_sign_string(:"place-gilmn"), do: "Gilman Sq"
  def destination_to_sign_string(:"place-gover"), do: "Gov't Ctr"
  def destination_to_sign_string(:"place-grigg"), do: "Griggs St"
  def destination_to_sign_string(:"place-grnst"), do: "Green St"
  def destination_to_sign_string(:"place-haecl"), do: "Haymarket"
  def destination_to_sign_string(:"place-harsq"), do: "Harvard"
  def destination_to_sign_string(:"place-harvd"), do: "Harvard Ave"
  def destination_to_sign_string(:"place-hsmnl"), do: "Heath St"
  def destination_to_sign_string(:"place-hwsst"), do: "Hawes St"
  def destination_to_sign_string(:"place-hymnl"), do: "Hynes"
  def destination_to_sign_string(:"place-jaksn"), do: "Jackson Sq"
  def destination_to_sign_string(:"place-jfk"), do: "JFK/Umass"
  def destination_to_sign_string(:"place-kencl"), do: "Kenmore"
  def destination_to_sign_string(:"place-knncl"), do: "Kendall/MIT"
  def destination_to_sign_string(:"place-kntst"), do: "Kent St"
  def destination_to_sign_string(:"place-lake"), do: "Boston Coll"
  def destination_to_sign_string(:"place-lech"), do: "Lechmere"
  def destination_to_sign_string(:"place-lngmd"), do: "Lngwd Med"
  def destination_to_sign_string(:"place-longw"), do: "Longwood"
  def destination_to_sign_string(:"place-masta"), do: "Mass Ave"
  def destination_to_sign_string(:"place-matt"), do: "Mattapan"
  def destination_to_sign_string(:"place-mdftf"), do: "Medfd/Tufts"
  def destination_to_sign_string(:"place-mfa"), do: "MFA"
  def destination_to_sign_string(:"place-mgngl"), do: "Magoun Sq"
  def destination_to_sign_string(:"place-miltt"), do: "Milton"
  def destination_to_sign_string(:"place-mispk"), do: "Mission Pk"
  def destination_to_sign_string(:"place-mlmnl"), do: "Malden Ctr"
  def destination_to_sign_string(:"place-mvbcl"), do: "Maverick"
  def destination_to_sign_string(:"place-newtn"), do: "Newton Hlnd"
  def destination_to_sign_string(:"place-newto"), do: "Newton Ctr"
  def destination_to_sign_string(:"place-north"), do: "North Sta"
  def destination_to_sign_string(:"place-nqncy"), do: "N Quincy"
  def destination_to_sign_string(:"place-nuniv"), do: "Northeast'n"
  def destination_to_sign_string(:"place-ogmnl"), do: "Oak Grove"
  def destination_to_sign_string(:"place-orhte"), do: "Orient Hts"
  def destination_to_sign_string(:"place-pktrm"), do: "Park St"
  def destination_to_sign_string(:"place-portr"), do: "Porter"
  def destination_to_sign_string(:"place-prmnl"), do: "Prudential"
  def destination_to_sign_string(:"place-qamnl"), do: "Quincy Adms"
  def destination_to_sign_string(:"place-qnctr"), do: "Quincy Ctr"
  def destination_to_sign_string(:"place-rbmnl"), do: "Revere Bch"
  def destination_to_sign_string(:"place-rcmnl"), do: "Roxbury Xng"
  def destination_to_sign_string(:"place-river"), do: "Riverside"
  def destination_to_sign_string(:"place-rsmnl"), do: "Reservoir"
  def destination_to_sign_string(:"place-rugg"), do: "Ruggles"
  def destination_to_sign_string(:"place-rvrwy"), do: "Riverway"
  def destination_to_sign_string(:"place-sbmnl"), do: "Stony Brook"
  def destination_to_sign_string(:"place-sdmnl"), do: "Suffolk Dns"
  def destination_to_sign_string(:"place-shmnl"), do: "Savin Hill"
  def destination_to_sign_string(:"place-smary"), do: "St. Mary's"
  def destination_to_sign_string(:"place-smmnl"), do: "Shawmut"
  def destination_to_sign_string(:"place-sougr"), do: "South St"
  def destination_to_sign_string(:"place-spmnl"), do: "Science Pk"
  def destination_to_sign_string(:"place-sstat"), do: "South Sta"
  def destination_to_sign_string(:"place-state"), do: "State"
  def destination_to_sign_string(:"place-sthld"), do: "Sutherland"
  def destination_to_sign_string(:"place-stpul"), do: "St. Paul St"
  def destination_to_sign_string(:"place-sull"), do: "Sullivan Sq"
  def destination_to_sign_string(:"place-sumav"), do: "Summit Ave"
  def destination_to_sign_string(:"place-symcl"), do: "Symphony"
  def destination_to_sign_string(:"place-tapst"), do: "Tappan St"
  def destination_to_sign_string(:"place-tumnl"), do: "Tufts Med"
  def destination_to_sign_string(:"place-unsqu"), do: "Union Sq"
  def destination_to_sign_string(:"place-valrd"), do: "Valley Rd"
  def destination_to_sign_string(:"place-waban"), do: "Waban"
  def destination_to_sign_string(:"place-wascm"), do: "Washington"
  def destination_to_sign_string(:"place-welln"), do: "Wellington"
  def destination_to_sign_string(:"place-wimnl"), do: "Wood Island"
  def destination_to_sign_string(:"place-wlsta"), do: "Wollaston"
  def destination_to_sign_string(:"place-wondl"), do: "Wonderland"
  def destination_to_sign_string(:"place-woodl"), do: "Woodland"
  def destination_to_sign_string(:"place-wrnst"), do: "Warren St"
  def destination_to_sign_string(:silver_line), do: "SL Outbound"
  def destination_to_sign_string(:southbound), do: "Southbound"
  def destination_to_sign_string(:westbound), do: "Westbound"

  def destination_to_sign_string(destination) do
    Logger.error("Unknown destination: #{inspect(destination)}")
    ""
  end

  @spec destination_to_ad_hoc_string(PaEss.destination()) :: String.t()
  def destination_to_ad_hoc_string(:eastboound), do: "Eastbound"
  def destination_to_ad_hoc_string(:inbound), do: "Inbound"
  def destination_to_ad_hoc_string(:northbound), do: "Northbound"
  def destination_to_ad_hoc_string(:outbound), do: "Outbound"
  def destination_to_ad_hoc_string(:"place-alfcl"), do: "Alewife"
  def destination_to_ad_hoc_string(:"place-alsgr"), do: "Allston Street"
  def destination_to_ad_hoc_string(:"place-amory"), do: "Amory Street"
  def destination_to_ad_hoc_string(:"place-andrw"), do: "Andrew"
  def destination_to_ad_hoc_string(:"place-aport"), do: "Airport"
  def destination_to_ad_hoc_string(:"place-aqucl"), do: "Aquarium"
  def destination_to_ad_hoc_string(:"place-armnl"), do: "Arlington"
  def destination_to_ad_hoc_string(:"place-asmnl"), do: "Ashmont"
  def destination_to_ad_hoc_string(:"place-astao"), do: "Assembly"
  def destination_to_ad_hoc_string(:"place-babck"), do: "Babcock Street"
  def destination_to_ad_hoc_string(:"place-balsq"), do: "Ball Square"
  def destination_to_ad_hoc_string(:"place-bbsta"), do: "Back Bay"
  def destination_to_ad_hoc_string(:"place-bckhl"), do: "Back of the Hill"
  def destination_to_ad_hoc_string(:"place-bcnfd"), do: "Beaconsfield"
  def destination_to_ad_hoc_string(:"place-bcnwa"), do: "Washington Square"
  def destination_to_ad_hoc_string(:"place-bland"), do: "Blandford Street"
  def destination_to_ad_hoc_string(:"place-bmmnl"), do: "Beachmont"
  def destination_to_ad_hoc_string(:"place-bndhl"), do: "Brandon Hall"
  def destination_to_ad_hoc_string(:"place-bomnl"), do: "Bowdoin"
  def destination_to_ad_hoc_string(:"place-boyls"), do: "Boylston"
  def destination_to_ad_hoc_string(:"place-brdwy"), do: "Broadway"
  def destination_to_ad_hoc_string(:"place-brico"), do: "Packard's Corner"
  def destination_to_ad_hoc_string(:"place-brkhl"), do: "Brookline Hills"
  def destination_to_ad_hoc_string(:"place-brmnl"), do: "Brigham Circle"
  def destination_to_ad_hoc_string(:"place-brntn"), do: "Braintree"
  def destination_to_ad_hoc_string(:"place-bucen"), do: "Boston University Central"
  def destination_to_ad_hoc_string(:"place-buest"), do: "Boston University East"
  def destination_to_ad_hoc_string(:"place-butlr"), do: "Butler"
  def destination_to_ad_hoc_string(:"place-bvmnl"), do: "Brookline Village"
  def destination_to_ad_hoc_string(:"place-capst"), do: "Capen Street"
  def destination_to_ad_hoc_string(:"place-ccmnl"), do: "Community College"
  def destination_to_ad_hoc_string(:"place-cedgr"), do: "Cedar Grove"
  def destination_to_ad_hoc_string(:"place-cenav"), do: "Central Avenue"
  def destination_to_ad_hoc_string(:"place-chels"), do: "Chelsea"
  def destination_to_ad_hoc_string(:"place-chhil"), do: "Chestnut Hill"
  def destination_to_ad_hoc_string(:"place-chill"), do: "Chestnut Hill Avenue"
  def destination_to_ad_hoc_string(:"place-chmnl"), do: "Charles/MGH"
  def destination_to_ad_hoc_string(:"place-chncl"), do: "Chinatown"
  def destination_to_ad_hoc_string(:"place-chswk"), do: "Chiswick Road"
  def destination_to_ad_hoc_string(:"place-clmnl"), do: "Cleveland Circle"
  def destination_to_ad_hoc_string(:"place-cntsq"), do: "Central"
  def destination_to_ad_hoc_string(:"place-coecl"), do: "Copley"
  def destination_to_ad_hoc_string(:"place-cool"), do: "Coolidge Corner"
  def destination_to_ad_hoc_string(:"place-davis"), do: "Davis"
  def destination_to_ad_hoc_string(:"place-denrd"), do: "Dean Road"
  def destination_to_ad_hoc_string(:"place-dwnxg"), do: "Downtown Crossing"
  def destination_to_ad_hoc_string(:"place-eliot"), do: "Eliot"
  def destination_to_ad_hoc_string(:"place-engav"), do: "Englewood Avenue"
  def destination_to_ad_hoc_string(:"place-esomr"), do: "East Somerville"
  def destination_to_ad_hoc_string(:"place-fbkst"), do: "Fairbanks Street"
  def destination_to_ad_hoc_string(:"place-fenwd"), do: "Fenwood Road"
  def destination_to_ad_hoc_string(:"place-fenwy"), do: "Fenway"
  def destination_to_ad_hoc_string(:"place-fldcr"), do: "Fields Corner"
  def destination_to_ad_hoc_string(:"place-forhl"), do: "Forest Hills"
  def destination_to_ad_hoc_string(:"place-gilmn"), do: "Gilman Square"
  def destination_to_ad_hoc_string(:"place-gover"), do: "Government Center"
  def destination_to_ad_hoc_string(:"place-grigg"), do: "Griggs Street"
  def destination_to_ad_hoc_string(:"place-grnst"), do: "Green Street"
  def destination_to_ad_hoc_string(:"place-haecl"), do: "Haymarket"
  def destination_to_ad_hoc_string(:"place-harsq"), do: "Harvard"
  def destination_to_ad_hoc_string(:"place-harvd"), do: "Harvard Avenue"
  def destination_to_ad_hoc_string(:"place-hsmnl"), do: "Heath Street"
  def destination_to_ad_hoc_string(:"place-hwsst"), do: "Hawes Street"
  def destination_to_ad_hoc_string(:"place-hymnl"), do: "Hynes Convention Center"
  def destination_to_ad_hoc_string(:"place-jaksn"), do: "Jackson Square"
  def destination_to_ad_hoc_string(:"place-jfk"), do: "JFK/UMass"
  def destination_to_ad_hoc_string(:"place-kencl"), do: "Kenmore"
  def destination_to_ad_hoc_string(:"place-knncl"), do: "Kendall/MIT"
  def destination_to_ad_hoc_string(:"place-kntst"), do: "Kent Street"
  def destination_to_ad_hoc_string(:"place-lake"), do: "Boston College"
  def destination_to_ad_hoc_string(:"place-lech"), do: "Lechmere"
  def destination_to_ad_hoc_string(:"place-lngmd"), do: "Longwood Medical Area"
  def destination_to_ad_hoc_string(:"place-longw"), do: "Longwood"
  def destination_to_ad_hoc_string(:"place-masta"), do: "Massachusetts Avenue"
  def destination_to_ad_hoc_string(:"place-matt"), do: "Mattapan"
  def destination_to_ad_hoc_string(:"place-mdftf"), do: "Medford/Tufts"
  def destination_to_ad_hoc_string(:"place-mfa"), do: "Museum of Fine Arts"
  def destination_to_ad_hoc_string(:"place-mgngl"), do: "Magoun Square"
  def destination_to_ad_hoc_string(:"place-miltt"), do: "Milton"
  def destination_to_ad_hoc_string(:"place-mispk"), do: "Mission Park"
  def destination_to_ad_hoc_string(:"place-mlmnl"), do: "Malden Center"
  def destination_to_ad_hoc_string(:"place-mvbcl"), do: "Maverick"
  def destination_to_ad_hoc_string(:"place-newtn"), do: "Newton Highlands"
  def destination_to_ad_hoc_string(:"place-newto"), do: "Newton Centre"
  def destination_to_ad_hoc_string(:"place-north"), do: "North Station"
  def destination_to_ad_hoc_string(:"place-nqncy"), do: "North Quincy"
  def destination_to_ad_hoc_string(:"place-nuniv"), do: "Northeastern University"
  def destination_to_ad_hoc_string(:"place-ogmnl"), do: "Oak Grove"
  def destination_to_ad_hoc_string(:"place-orhte"), do: "Orient Heights"
  def destination_to_ad_hoc_string(:"place-pktrm"), do: "Park Street"
  def destination_to_ad_hoc_string(:"place-portr"), do: "Porter"
  def destination_to_ad_hoc_string(:"place-prmnl"), do: "Prudential"
  def destination_to_ad_hoc_string(:"place-qamnl"), do: "Quincy Adams"
  def destination_to_ad_hoc_string(:"place-qnctr"), do: "Quincy Center"
  def destination_to_ad_hoc_string(:"place-rbmnl"), do: "Revere Beach"
  def destination_to_ad_hoc_string(:"place-rcmnl"), do: "Roxbury Crossing"
  def destination_to_ad_hoc_string(:"place-river"), do: "Riverside"
  def destination_to_ad_hoc_string(:"place-rsmnl"), do: "Reservoir"
  def destination_to_ad_hoc_string(:"place-rugg"), do: "Ruggles"
  def destination_to_ad_hoc_string(:"place-rvrwy"), do: "Riverway"
  def destination_to_ad_hoc_string(:"place-sbmnl"), do: "Stony Brook"
  def destination_to_ad_hoc_string(:"place-sdmnl"), do: "Suffolk Downs"
  def destination_to_ad_hoc_string(:"place-shmnl"), do: "Savin Hill"
  def destination_to_ad_hoc_string(:"place-smary"), do: "Saint Mary's Street"
  def destination_to_ad_hoc_string(:"place-smmnl"), do: "Shawmut"
  def destination_to_ad_hoc_string(:"place-sougr"), do: "South Street"
  def destination_to_ad_hoc_string(:"place-spmnl"), do: "Science Park/West End"
  def destination_to_ad_hoc_string(:"place-sstat"), do: "South Station"
  def destination_to_ad_hoc_string(:"place-state"), do: "State"
  def destination_to_ad_hoc_string(:"place-sthld"), do: "Sutherland Road"
  def destination_to_ad_hoc_string(:"place-stpul"), do: "Saint Paul Street"
  def destination_to_ad_hoc_string(:"place-sull"), do: "Sullivan Square"
  def destination_to_ad_hoc_string(:"place-sumav"), do: "Summit Avenue"
  def destination_to_ad_hoc_string(:"place-symcl"), do: "Symphony"
  def destination_to_ad_hoc_string(:"place-tapst"), do: "Tappan Street"
  def destination_to_ad_hoc_string(:"place-tumnl"), do: "Tufts Medical Center"
  def destination_to_ad_hoc_string(:"place-unsqu"), do: "Union Square"
  def destination_to_ad_hoc_string(:"place-valrd"), do: "Valley Road"
  def destination_to_ad_hoc_string(:"place-waban"), do: "Waban"
  def destination_to_ad_hoc_string(:"place-wascm"), do: "Washington Street"
  def destination_to_ad_hoc_string(:"place-welln"), do: "Wellington"
  def destination_to_ad_hoc_string(:"place-wimnl"), do: "Wood Island"
  def destination_to_ad_hoc_string(:"place-wlsta"), do: "Wollaston"
  def destination_to_ad_hoc_string(:"place-wondl"), do: "Wonderland"
  def destination_to_ad_hoc_string(:"place-woodl"), do: "Woodland"
  def destination_to_ad_hoc_string(:"place-wrnst"), do: "Warren Street"
  def destination_to_ad_hoc_string(:silver_line), do: "Silver Line Outbound"
  def destination_to_ad_hoc_string(:southbound), do: "Southbound"
  def destination_to_ad_hoc_string(:westbound), do: "Westbound"

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

    if route_text do
      "#{route_text} train to #{destination_text}"
    else
      "#{destination_text} train"
    end
  end

  @spec train_description_tokens(PaEss.destination(), String.t() | nil) :: [atom()]
  @spec train_description_tokens(PaEss.destination(), String.t() | nil, boolean()) :: [atom()]
  def train_description_tokens(destination, route_id, use_polly_takes? \\ false) do
    branch = Content.Utilities.route_branch_letter(route_id)
    tokens = if branch, do: [branch, :train_to, destination], else: [destination, :train]
    if use_polly_takes?, do: Enum.map(tokens, &to_polly_take/1), else: tokens
  end

  defp to_polly_take(:"place-alfcl"), do: :alewife_
  defp to_polly_take(:"place-asmnl"), do: :ashmont_
  defp to_polly_take(:"place-brntn"), do: :braintree_
  defp to_polly_take(:"place-matt"), do: :mattapan_
  defp to_polly_take(:"place-bomnl"), do: :bowdoin_
  defp to_polly_take(:"place-wondl"), do: :wonderland_
  defp to_polly_take(:"place-ogmnl"), do: :oak_grove_
  defp to_polly_take(:"place-forhl"), do: :forest_hills_
  defp to_polly_take(:"place-lech"), do: :lechmere_
  defp to_polly_take(:"place-north"), do: :north_station_
  defp to_polly_take(:"place-gover"), do: :government_center_
  defp to_polly_take(:"place-pktrm"), do: :park_street_
  defp to_polly_take(:"place-kencl"), do: :kenmore_
  defp to_polly_take(:"place-lake"), do: :boston_college_
  defp to_polly_take(:"place-clmnl"), do: :cleveland_circle_
  defp to_polly_take(:"place-rsmnl"), do: :reservoir_
  defp to_polly_take(:"place-river"), do: :riverside_
  defp to_polly_take(:"place-hsmnl"), do: :heath_street_
  defp to_polly_take(:b), do: :b_
  defp to_polly_take(:c), do: :c_
  defp to_polly_take(:d), do: :d_
  defp to_polly_take(:e), do: :e_
  defp to_polly_take(:train), do: :train_
  defp to_polly_take(:train_to), do: :train_to_
  defp to_polly_take(:there_is_no), do: :there_is_no_
  # Use token as-is when there is no Polly take or the Polly take is the only one
  defp to_polly_take(token), do: token

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
    {"Design Center", ["Design Ctr"]},
    {"Silver Line Way", ["SL Way"]},
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

  @spec audio_take(term()) :: String.t()
  # Tokens ending in underscores are newer Polly-generated clips
  def audio_take(:eastbound), do: "867"
  def audio_take(:inbound), do: "33003"
  def audio_take(:northbound), do: "788"
  def audio_take(:outbound), do: "33004"
  def audio_take(:"place-alfcl"), do: "4000"
  def audio_take(:"place-alsgr"), do: "4210"
  def audio_take(:"place-amory"), do: "4211"
  def audio_take(:"place-andrw"), do: "4011"
  def audio_take(:"place-aport"), do: "4050"
  def audio_take(:"place-aqucl"), do: "4052"
  def audio_take(:"place-armnl"), do: "4065"
  def audio_take(:"place-asmnl"), do: "4016"
  def audio_take(:"place-astao"), do: "4209"
  def audio_take(:"place-babck"), do: "4212"
  def audio_take(:"place-balsq"), do: "4214"
  def audio_take(:"place-bbsta"), do: "4036"
  def audio_take(:"place-bckhl"), do: "4213"
  def audio_take(:"place-bcnfd"), do: "4075"
  def audio_take(:"place-bcnwa"), do: "4255"
  def audio_take(:"place-bland"), do: "4215"
  def audio_take(:"place-bmmnl"), do: "4046"
  def audio_take(:"place-bndhl"), do: "4218"
  def audio_take(:"place-bomnl"), do: "4055"
  def audio_take(:"place-boyls"), do: "4064"
  def audio_take(:"place-brdwy"), do: "4010"
  def audio_take(:"place-brico"), do: "4244"
  def audio_take(:"place-brkhl"), do: "4074"
  def audio_take(:"place-brmnl"), do: "4205"
  def audio_take(:"place-brntn"), do: "4021"
  def audio_take(:"place-bucen"), do: "4216"
  def audio_take(:"place-buest"), do: "4217"
  def audio_take(:"place-butlr"), do: "4095"
  def audio_take(:"place-bvmnl"), do: "4073"
  def audio_take(:"place-capst"), do: "4099"
  def audio_take(:"place-ccmnl"), do: "4026"
  def audio_take(:"place-cedgr"), do: "4094"
  def audio_take(:"place-cenav"), do: "4097"
  def audio_take(:"place-chels"), do: "860"
  def audio_take(:"place-chhil"), do: "4078"
  def audio_take(:"place-chill"), do: "4219"
  def audio_take(:"place-chmnl"), do: "4006"
  def audio_take(:"place-chncl"), do: "4220"
  def audio_take(:"place-chswk"), do: "4221"
  def audio_take(:"place-clmnl"), do: "4203"
  def audio_take(:"place-cntsq"), do: "4004"
  def audio_take(:"place-coecl"), do: "4223"
  def audio_take(:"place-cool"), do: "4222"
  def audio_take(:"place-davis"), do: "4001"
  def audio_take(:"place-denrd"), do: "4224"
  def audio_take(:"place-dwnxg"), do: "4008"
  def audio_take(:"place-eliot"), do: "4081"
  def audio_take(:"place-engav"), do: "4226"
  def audio_take(:"place-esomr"), do: "4225"
  def audio_take(:"place-fbkst"), do: "4227"
  def audio_take(:"place-fenwd"), do: "4228"
  def audio_take(:"place-fenwy"), do: "4206"
  def audio_take(:"place-fldcr"), do: "4229"
  def audio_take(:"place-forhl"), do: "4043"
  def audio_take(:"place-gilmn"), do: "4230"
  def audio_take(:"place-gover"), do: "4054"
  def audio_take(:"place-grigg"), do: "4231"
  def audio_take(:"place-grnst"), do: "4042"
  def audio_take(:"place-haecl"), do: "751"
  def audio_take(:"place-harsq"), do: "4003"
  def audio_take(:"place-harvd"), do: "4232"
  def audio_take(:"place-hsmnl"), do: "4204"
  def audio_take(:"place-hwsst"), do: "4233"
  def audio_take(:"place-hymnl"), do: "4234"
  def audio_take(:"place-jaksn"), do: "4040"
  def audio_take(:"place-jfk"), do: "4012"
  def audio_take(:"place-kencl"), do: "4070"
  def audio_take(:"place-knncl"), do: "4005"
  def audio_take(:"place-kntst"), do: "4235"
  def audio_take(:"place-lake"), do: "4202"
  def audio_take(:"place-lech"), do: "4056"
  def audio_take(:"place-lngmd"), do: "4236"
  def audio_take(:"place-longw"), do: "4072"
  def audio_take(:"place-masta"), do: "4239"
  def audio_take(:"place-matt"), do: "4100"
  def audio_take(:"place-mdftf"), do: "852"
  def audio_take(:"place-mfa"), do: "4241"
  def audio_take(:"place-mgngl"), do: "4237"
  def audio_take(:"place-miltt"), do: "4096"
  def audio_take(:"place-mispk"), do: "4240"
  def audio_take(:"place-mlmnl"), do: "4238"
  def audio_take(:"place-mvbcl"), do: "4051"
  def audio_take(:"place-newtn"), do: "4080"
  def audio_take(:"place-newto"), do: "4242"
  def audio_take(:"place-north"), do: "4027"
  def audio_take(:"place-nqncy"), do: "4017"
  def audio_take(:"place-nuniv"), do: "4243"
  def audio_take(:"place-ogmnl"), do: "4022"
  def audio_take(:"place-orhte"), do: "4048"
  def audio_take(:"place-pktrm"), do: "4007"
  def audio_take(:"place-portr"), do: "4002"
  def audio_take(:"place-prmnl"), do: "4068"
  def audio_take(:"place-qamnl"), do: "4020"
  def audio_take(:"place-qnctr"), do: "620"
  def audio_take(:"place-rbmnl"), do: "4045"
  def audio_take(:"place-rcmnl"), do: "4039"
  def audio_take(:"place-river"), do: "4084"
  def audio_take(:"place-rsmnl"), do: "4076"
  def audio_take(:"place-rugg"), do: "4038"
  def audio_take(:"place-rvrwy"), do: "4245"
  def audio_take(:"place-sbmnl"), do: "4041"
  def audio_take(:"place-sdmnl"), do: "4047"
  def audio_take(:"place-shmnl"), do: "4013"
  def audio_take(:"place-smary"), do: "4246"
  def audio_take(:"place-smmnl"), do: "4015"
  def audio_take(:"place-sougr"), do: "4249"
  def audio_take(:"place-spmnl"), do: "4248"
  def audio_take(:"place-sstat"), do: "4009"
  def audio_take(:"place-state"), do: "4053"
  def audio_take(:"place-sthld"), do: "4251"
  def audio_take(:"place-stpul"), do: "4247"
  def audio_take(:"place-sull"), do: "4025"
  def audio_take(:"place-sumav"), do: "4250"
  def audio_take(:"place-symcl"), do: "4069"
  def audio_take(:"place-tapst"), do: "4252"
  def audio_take(:"place-tumnl"), do: "4253"
  def audio_take(:"place-unsqu"), do: "565"
  def audio_take(:"place-valrd"), do: "4098"
  def audio_take(:"place-waban"), do: "4082"
  def audio_take(:"place-wascm"), do: "4256"
  def audio_take(:"place-welln"), do: "4024"
  def audio_take(:"place-wimnl"), do: "4049"
  def audio_take(:"place-wlsta"), do: "4018"
  def audio_take(:"place-wondl"), do: "4044"
  def audio_take(:"place-woodl"), do: "4083"
  def audio_take(:"place-wrnst"), do: "4254"
  def audio_take(:silver_line), do: "931"
  def audio_take(:southbound), do: "787"
  def audio_take(:westbound), do: "868"

  def audio_take(:ashmont), do: "4016"
  def audio_take(:braintree), do: "4021"
  def audio_take(:alewife_), do: "892"
  def audio_take(:ashmont_), do: "895"
  def audio_take(:braintree_), do: "902"
  def audio_take(:mattapan_), do: "913"
  def audio_take(:bowdoin_), do: "900"
  def audio_take(:wonderland_), do: "921"
  def audio_take(:oak_grove_), do: "915"
  def audio_take(:forest_hills_), do: "907"
  def audio_take(:lechmere_), do: "912"
  def audio_take(:north_station_), do: "914"
  def audio_take(:government_center_), do: "908"
  def audio_take(:park_street_), do: "916"
  def audio_take(:kenmore_), do: "911"
  def audio_take(:boston_college_), do: "899"
  def audio_take(:cleveland_circle_), do: "904"
  def audio_take(:reservoir_), do: "917"
  def audio_take(:riverside_), do: "918"
  def audio_take(:heath_street_), do: "909"
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
  def audio_take(:departs_at), do: "927"
  def audio_take(:upcoming_departures), do: "548"
  def audio_take(:upcoming_arrivals), do: "550"
  def audio_take(:is_now_arriving), do: "24055"
  def audio_take(:does_not_take_passengers), do: "933"
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
  def audio_take(:arrives_every), do: "666"
  def audio_take(:to), do: "511"
  def audio_take(:buses), do: "932"

  # audio: "It is a shorter 4-car train. Move toward the front of the train to board, and stand back from the platform edge.", visual: "Please move to front of the train to board."
  def audio_take(:four_car_train_message), do: "922"

  # audio: "It is a shorter 4-car train. You may have to move to a different part of the platform to board."
  def audio_take(:four_car_train_boarding_message), do: "926"
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

  def audio_take({:crowding, {:front, _status}}), do: "870"
  def audio_take({:crowding, {:back, _status}}), do: "871"
  def audio_take({:crowding, {:middle, _status}}), do: "872"
  def audio_take({:crowding, {:front_and_back, _status}}), do: "873"
  def audio_take({:crowding, {:train_level, :crowded}}), do: "876"
  def audio_take({:crowding, _crowding_description}), do: "21000"

  def audio_take({:line, "Red"}), do: "3005"
  def audio_take({:line, "Orange"}), do: "3006"
  def audio_take({:line, "Blue"}), do: "3007"
  def audio_take({:line, "Green"}), do: "3008"
  def audio_take({:line, "Mattapan"}), do: "3009"
  def audio_take({:line, _name}), do: audio_take(:train)

  def audio_take(item) do
    Logger.error("No audio for: #{inspect(item)}")
    "21000"
  end

  @spec audio_message([term()]) :: Content.Audio.canned_message()
  def audio_message(items, av \\ :audio) do
    vars = Enum.map(items, &audio_take/1) |> pad_takes()
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

  def sign_length(scu_id) when scu_id in @short_sign_scu_ids, do: :short
  def sign_length(_), do: :long

  def max_text_length(scu_id) when scu_id in @short_sign_scu_ids, do: @short_width
  def max_text_length(_), do: @width
end
