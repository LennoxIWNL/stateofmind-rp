Config = {
    -- The courts pay from the doj business, which the fines share funds.
    business = 'doj',
    fee = 250,

    holdMinutes = 30,
    -- A hearing nearer than this is too late to be worth serving.
    hearingMinutes = 15,
    listSize = 12,

    seconds = 6,
    staleSeconds = 60,
    distance = 3.0,

    hourlyCap = 1000,
    -- The same defendant can be served for a fee once per this many hours,
    -- across all their cases, so a friend cannot be served over and over.
    defendantHours = 24,

    callMs = 2000,
}
