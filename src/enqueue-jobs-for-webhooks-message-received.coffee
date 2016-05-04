http           = require 'http'
WebhookManager = require 'meshblu-core-manager-webhook'

class EnqueueJobsForWebhooksMessageReceived
  constructor: (options) ->
    {datastore, jobManager, uuidAliasResolver} = options
    @webhookManager = new WebhookManager {datastore, jobManager, uuidAliasResolver}

  do: (request, callback) =>
    @webhookManager.enqueueForReceived {
      uuid: request.metadata.auth.uuid
      route: request.metadata.route
      forwardedRoutes: request.metadata.forwardedRoutes
      rawData: request.rawData
      type: 'message.received'
    }, (error) =>
      return @_doErrorCallback request, error, callback if error?
      @_doCallback request, 204, callback

  _doCallback: (request, code, callback) =>
    response =
      metadata:
        responseId: request.metadata.responseId
        code: code
        status: http.STATUS_CODES[code]
    callback null, response

  _doErrorCallback: (request, error, callback) =>
    code = error.code ? 500
    @_doCallback request, code, callback

module.exports = EnqueueJobsForWebhooksMessageReceived
