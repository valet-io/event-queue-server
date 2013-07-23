Firebase = require 'firebase'
IronMQ = require 'iron_mq'

firebaseConfig = require './firebase.json'
eventsRef = new Firebase(firebaseConfig.endpoint + firebaseConfig.collection)
claimedEventsRef = new Firebase(firebaseConfig.endpoint + 'claimed-events')
expiredEventsRef = new Firebase(firebaseConfig.endpoint + 'expired-events')
apiKeysRef = new Firebase(firebaseConfig.endpoint + 'riqApiKeys')

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

claimEvent = (event, cb) ->
	riqListId = '51e720bbe4b0135ef0caa976'

	apiKey = apiKeys[event.claimed]

	relationship =
		firstName: event.contact_name
		email: event.contact_email
		relationshipName: event.organization

pruneOldEvents = () ->
	getEvents (events) ->
		for id, event of events
			if Date.parse(event.date) < ((new Date).getTime() + 1000 * 60 * 60 * 24 * 7 * 4)
				eventsRef.child(id).remove()
				expiredEventsRef.push event

getEvents = (cb) ->
	eventsRef.once 'value', (snapshot) ->
		cb snapshot.val()

eventsRef.on 'child_changed', (snapshot) ->
	event = snapshot.val()
	id = snapshot.name()
	if event.claimed
		eventsRef.child(id).remove()
		claimedEventsRef.push() event

claimedEventsRef.on 'child_added', (snapshot) ->
	claimEvent snapshot.val(), () ->

eventsRef.on 'value', (snapshot) ->
	events = snapshot.val()

apiKeysRef.on 'value', (snapshot) ->
	apiKeys = snapshot.val()

setInterval () ->
	readNextEvent insertEvent
, 1000

setInterval () ->
	pruneOldEvents()
, 86400000

pruneOldEvents()