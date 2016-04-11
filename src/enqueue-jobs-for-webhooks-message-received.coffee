_     = require 'lodash'
async = require 'async'
http  = require 'http'

class EnqueueJobsForWebhooksMessageReceived
  constructor: (options) ->
    {@datastore, @jobManager, @uuidAliasResolver} = options

  _doCallback: (request, code, callback) =>
    response =
      metadata:
        responseId: request.metadata.responseId
        code: code
        status: http.STATUS_CODES[code]
    callback null, response

  do: (request, callback) =>
    {uuid} = request.metadata.auth
    lastHop    = _.first request.metadata.route
    return @_doCallback request, 422, callback unless lastHop?
    {from, to} = lastHop

    @_resolveUuids {from, to, uuid}, (error, results) =>
      return @_doCallback request, 500, callback if error?
      {from, to, uuid} = results
      return @_doCallback request, 204, callback unless from == to

      @datastore.findOne {uuid}, (error, device) =>
        return @_doCallback request, 500, callback if error?
        return @_doCallback request, 500, callback unless device?

        webhooks = _.filter device.meshblu?.forwarders?.message?.received, type: 'webhook'
        async.eachSeries webhooks, async.apply(@_createRequest, uuid, request), (error) =>
          return @_doCallback request, 500, callback if error?
          return @_doCallback request, 204, callback

  _createRequest: (uuid, request, webhook, callback) =>
    @jobManager.createRequest 'request', {
      metadata:
        jobType: 'DeliverWebhook'
        auth:     {uuid}
        fromUuid: uuid
        toUuid:   uuid
        messageType: 'message.received'
        route: request.metadata.route
        options: webhook
      rawData: request.rawData
    }, callback

  _resolveUuids: ({from, to, uuid}, callback) =>
    async.series {
      from: async.apply @uuidAliasResolver.resolve, from
      to:   async.apply @uuidAliasResolver.resolve, to
      uuid: async.apply @uuidAliasResolver.resolve, uuid
    }, callback

module.exports = EnqueueJobsForWebhooksMessageReceived
