# Description
#   Emit review-needed and review-complete events based on GitHub pull_request WebHook Events
module.exports = (robot) ->

  # TODO: move webhook listener and  event emission logic to its own module
  robot.router.post '/hubot/gh', (req, res) ->
    robot.logger.debug 'hubot/gh webhook request received'
    res.send 200
    return if req.body.zen
    if req.body.action == 'labeled' && req.body.label.name == process.env.HUBOT_REVIEW_NEEDED_LABEL
      robot.logger.info "emitting review-needed event: url: #{req.body.pull_request.html_url}"
      robot.emit 'review-needed',
        url: req.body.pull_request.html_url
        repo: req.body.repository.full_name
        number: req.body.number
    if reviewNoLongerNeeded req.body
      robot.logger.info "emitting review-complete event: url: #{req.body.pull_request.html_url}"
      robot.emit 'review-complete',
        url: req.body.pull_request.html_url
        repo: req.body.repository.full_name
        number: req.pull_request.number

  reviewNoLongerNeeded = (body) ->
    labelRemoved = body.action == 'unlabeled' && body.label.name == process.env.HUBOT_REVIEW_NEEDED_LABEL
    #TODO: don't have label in body, must see if name exists in needs review list instead
    prClosed = body.action == 'closed' && prNeedsReview "#{body.repository.full_name}/#{body.number}"
    labelRemoved || prClosed

  prNeedsReview = (prKey) ->
    robot.brain.data.prsForReview[prKey]

