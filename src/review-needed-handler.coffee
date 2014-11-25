# Description
#   Message AOs and persist review info on review-needed events
AOHelper = require './models/ActiveOwnerHelper'

module.exports = (robot) ->

  helper = new AOHelper robot
  
  robot.on 'review-needed', (review) ->
    helper.addReview(review)
    message = "Rapid Response needs a review of #{review.url}"
    helper.messageAOs(message)
