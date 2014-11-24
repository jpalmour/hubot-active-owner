class PullRequest
  constructor: (pr) ->
    @repo = pr.repo
    @url = pr.url
    @number = pr.number
    @reviewNeededDt = new Date()

module.exports = PullRequest
