# Description
#   Message AOs and remove PRs from review list on review-complete events
AOHelper = require './models/ActiveOwnerHelper'

module.exports = (robot) ->

  helper = new AOHelper robot

  robot.on 'review-complete', (review) ->
    helper.removeReview(review.key)
    message = "Review no longer needed for #{review.url}. The PR either was closed or review label was removed."
    helper.messageAOs message
