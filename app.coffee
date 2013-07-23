Firebase = require 'firebase'
IronMQ = require 'iron_mq'

firebaseConfig = require './firebase.json'
eventsRef = new Firebase(firebaseConfig.endpoint + firebaseConfig.collection)
claimedEventsRef = new Firebase(firebaseConfig.endpoint + 'claimed-events')

ironClient = new IronMQ.Client()
eventsQueue = ironClient.queue "scraped-events"

eventsRef.auth firebaseConfig.secret, (err) ->
	unless err
		console.log ">> Authentication succeeded"
	else
		console.log ">> Authentication failed"

readNextEvent = (cb) ->	
	eventsQueue.get {}, (err, body) ->
		unless err || typeof body == 'undefined'
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

claimEvent = (event) ->
	# TODO: Insert event 

eventsRef.on 'child_changed', (snapshot) ->
	event = snapshot.val()
	id = snapshot.name()
	if event.claimed
		claimedEventRef = new Firebase(firebaseConfig.endpoint + firebaseConfig.collection + '/' + id)
		claimedEventRef.remove()
		claimedEventsRef.push() event

eventsRef.on 'value', (snapshot) ->
	events = snapshot.val()

setInterval () ->
	readNextEvent insertEvent
, 1000