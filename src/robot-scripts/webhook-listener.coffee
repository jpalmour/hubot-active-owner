# Description
#   Emit review-needed and review-complete events based on
#   GitHub pull_request WebHook Events

AOHelper = require '../ActiveOwnerHelper'
Review = require '../Review'

module.exports = (robot) ->

  helper = new AOHelper robot

  robot.router.post '/hubot/gh', (req, res) ->
    robot.logger.debug 'GitHub webhook request received.'
    res.send 200
    return if ! req.body.pull_request
    robot.logger.debug "Processing pull_request event. " +
      "action: #{req.body.action}"
    review = new Review(req.body)
    if req.body.action == 'labeled' &&
    req.body.label.name == process.env.HUBOT_REVIEW_NEEDED_LABEL
      robot.logger.debug "Emitted review-needed event for " +
      "#{req.body.pull_request.html_url}"
      robot.emit 'review-needed', review
    if reviewNoLongerNeeded req.body
      robot.logger.debug "Emitted review-closed event for " +
      "#{req.body.pull_request.html_url}"
      robot.emit 'review-complete', review

  reviewNoLongerNeeded = (body) ->
    labelRemoved = body.action == 'unlabeled' &&
      body.label.name == process.env.HUBOT_REVIEW_NEEDED_LABEL
    prClosed = body.action == 'closed' &&
      helper.getReview "#{body.repository.full_name}/#{body.number}"
    labelRemoved || prClosed
