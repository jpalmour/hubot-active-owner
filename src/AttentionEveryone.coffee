class AttentionEveryone
    constructor: (prEvent) ->
        @repo = prEvent.repository.full_name
        @url = prEvent.pull_request.html_url
        @number = prEvent.number
        @reviewNeededDt = new Date()

module.exports = AttentionEveryone
