class ShadowcraftTiniReforgeBackend
  ENGINE = "http://shadowref.appspot.com/calc"
  REFORGABLE = ["spirit", "dodge_rating", "parry_rating", "hit_rating", "crit_rating", "haste_rating", "expertise_rating", "mastery_rating"]

  deferred = null
  constructor: (@gear) ->

  request: (req) ->
    deferred = $.Deferred()
    wait('Optimizing reforges...')
    Shadowcraft.Console.log "Starting reforge optimization...", "gold underline"
    if $.browser.msie and window.XDomainRequest
      @request_via_xdr req
    else
      @request_via_ajax req
    deferred.promise()

  request_via_xdr: (req) ->
    xdr = new XDomainRequest()
    # We have to use GET because Twisted expects a proper form header for POST data, which XDR can't send. Yay IE.

    xdr.open "post", ENGINE
    xdr.send JSON.stringify(req)
    xdr.onload = ->
      data = JSON.parse xdr.responseText
      Shadowcraft.Gear.setReforges(data)
      deferred.resolve()
    xdr.onerror ->
      flash "Error contacting reforging service"
    xdr.ontimeout ->
      flash "Timed out talking to reforging service"

  request_via_ajax: (req) ->
    $.ajax
      type: "POST"
      url: "http://shadowref.appspot.com/calc"
      data: json_encode(req)
      complete: ->
        deferred.resolve()
      success: (data) ->
        Shadowcraft.Gear.setReforges(data)
      error: (xhr, textStatus, error) ->
        flash textStatus
      dataType: "json",
      contentType: "application/json"

  buildRequest: ->
    ItemLookup = Shadowcraft.ServerData.ITEM_LOOKUP
    stats = @gear.sumStats(true)

    items = _.map(Shadowcraft.Data.gear, (e) ->
      r = { id: e.item_id }
      if ItemLookup[e.item_id]
        for key, val of ItemLookup[e.item_id].stats
          if REFORGABLE.indexOf(key) != -1
            r[key] = val
      r
    )

    items = _.select items, (i) ->
      for k, v of i
        if REFORGABLE.indexOf(k) != -1
          return true
      return false


    caps = @gear.getCaps()
    for k, v of caps
      caps[k] = Math.ceil(v)

    req =
      items: items
      ep: @gear.getWeights()
      cap: caps
      ratings: stats
    @request(req).then ->
      $("#wait").hide()
      Shadowcraft.Console.log "Finished reforge optimization!", "gold underline"
