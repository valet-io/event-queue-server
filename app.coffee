Firebase = require 'firebase'
IronMQ = require 'iron_mq'

firebaseConfig = require './firebase.json'

eventsRef = new Firebase(firebaseConfig.endpoint)

eventsRef.auth firebaseConfig.secret, (err) ->
	unless err
		console.log ">> Authentication succeeded"
	else
		console.log ">> Authentication failed"

eventsRef.on 'value', (snapshot) ->
	events = snapshot.val()
	console.log events