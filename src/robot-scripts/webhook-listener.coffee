# Description
#   Emit review-needed and review-complete events based on
#   GitHub pull_request WebHook Events

AOHelper = require '../ActiveOwnerHelper'
Review = require '../Review'
Push = require '../Push'

module.exports = (robot) ->

  helper = new AOHelper robot
  branchPattern = ///^refs/heads/release-[0-9.]*$///

  robot.router.post '/hubot/gh', (req, res) ->
    robot.logger.debug 'GitHub webhook request received.'
    test = req.body.ref
    res.send 200
    
    review = new Review(req.body) if req.body.pull_request
    push = new Push(req.body) if req.body.forced

    if req.body.action == 'labeled' and req.body.label.name == process.env.HUBOT_REVIEW_NEEDED_LABEL and req.body.pull_request
      robot.logger.debug "Emitted review-needed event for " +
      "#{req.body.pull_request.html_url}"
      robot.emit 'review-needed', review

    if req.body.pull_request and reviewNoLongerNeeded req.body
      robot.logger.debug "Emitted review-closed event for " +
      "#{req.body.pull_request.html_url}"
      robot.emit 'review-complete', review

    #push needs to be the last choice
    if req.body.forced and (test == 'refs/heads/master' or test.match branchPattern)
      robot.logger.debug "Emitted force-push notice" +
      "#{req.body.ref}"
      robot.emit 'force-push', push
    
  reviewNoLongerNeeded = (body) ->
    labelRemoved = body.action == 'unlabeled' &&
      body.label.name == process.env.HUBOT_REVIEW_NEEDED_LABEL
    prClosed = body.action == 'closed' &&
      helper.getReview "#{body.repository.full_name}/#{body.number}"
    labelRemoved || prClosed

