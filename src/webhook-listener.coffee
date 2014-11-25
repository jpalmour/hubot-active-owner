# Description
#   Emit review-needed and review-complete events based on GitHub pull_request WebHook Events

AOHelper = require './models/ActiveOwnerHelper'
Review = require './models/Review'

module.exports = (robot) ->

  helper = new AOHelper robot

  robot.router.post '/hubot/gh', (req, res) ->
    robot.logger.debug 'hubot/gh webhook request received'
    res.send 200
    return if ! req.body.pull_request
    review = new Review(req.body)
    if req.body.action == 'labeled' && req.body.label.name == process.env.HUBOT_REVIEW_NEEDED_LABEL
      robot.emit 'review-needed', review
    if reviewNoLongerNeeded req.body
      robot.emit 'review-complete', review

  reviewNoLongerNeeded = (body) ->
    labelRemoved = body.action == 'unlabeled' && body.label.name == process.env.HUBOT_REVIEW_NEEDED_LABEL
    prClosed = body.action == 'closed' && helper.getReview "#{body.repository.full_name}/#{body.number}"
    labelRemoved || prClosed
