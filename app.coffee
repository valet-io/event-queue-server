Firebase = require 'firebase'
IronMQ = require('iron_mq')

firebaseConfig = require './firebase.json'
eventsRef = new Firebase(firebaseConfig.endpoint)

ironClient = new IronMQ.Client()
eventsQueue = ironClient.queue "scraped-events"

eventsRef.auth firebaseConfig.secret, (err) ->
	unless err
		console.log ">> Authentication succeeded"
	else
		console.log ">> Authentication failed"

eventsRef.on 'value', (snapshot) ->
	events = snapshot.val()

readNextEvent = (cb) ->	
	eventsQueue.get {}, (err, body) ->
		unless err
			cb body

insertEvent = (message) ->
	event = JSON.parse message.body
	eventsRef.push().setWithPriority event, event.date.replace(/-/g,''), (err) ->
		if err
			console.log "Could not save event: #{event}"
		else
			deleteQueueItem message.id

deleteQueueItem = (id) ->
	eventsQueue.del id, (err, body) ->
		console.log err if err

setInterval () ->
	readNextEvent insertEvent
, 1000