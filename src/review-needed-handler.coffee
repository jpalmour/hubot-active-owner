# Description
#   Message AOs and persist review info on review-needed events
AOHelper = require './models/ActiveOwnerHelper'
PullRequest = require './models/PullRequest'

module.exports = (robot) ->

  helper = new AOHelper robot
  
  robot.on 'review-needed', (pullRequest) ->
    pr = new PullRequest(pullRequest)
    robot.brain.data.prsForReview["#{pr.repo}/#{pr.number}"] = pr
    message = "Rapid Response needs a review of #{pr.url}"
    helper.messageAOs(message)
