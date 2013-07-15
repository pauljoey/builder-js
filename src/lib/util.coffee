
fs     = require 'fs'
path   = require 'path'
crypto = require 'crypto'

exists = fs.existsSync || path.existsSync

try 
	growl = require('growl')
catch err
	growl = (msg) ->
		console.info(msg)


exports.debug = debug = () ->
	if arguments.length == 1 then console.log(arguments[0]) else console.log((i for i in arguments).join(',\t'))


exports.error = error = () ->
	if arguments.length == 1 then console.error(arguments[0]) else console.error((i for i in arguments).join(',\t'))
	growl arguments[0]


exports.warn = warn = () ->
	if arguments.length == 1 then console.warn(arguments[0]) else console.warn((i for i in arguments).join(',\t'))

exports.info = info = () ->
	if arguments.length == 1 then console.info(arguments[0]) else console.info((i for i in arguments).join(',\t'))


exports.abort = abort = () ->
	error.apply(this, arguments) # Pass arguments directly to error() function
	arguments.handled_error = true
	throw arguments

exports.notify = notify = (message) ->
	growl message

# Borrowed snippet
exports.uuid4 = uuid4 = (a, b) ->
	b = a = ""
	while a++ < 36
		b += (if a * 51 & 52 then (if a ^ 15 then 8 ^ Math.random() * (if a ^ 20 then 16 else 4) else 4).toString(16) else "-")
	return b



exports.sha256 = sha256 = (data) ->
	return crypto.createHash('sha256').update(data).digest("hex")


exports.timestamp = timestamp = (time) ->

	year = time.getFullYear()
	hour = time.getHours()
	min = time.getMinutes()
	month = time.getMonth()
	day = time.getDate()

	ret = String(year)
	if month+1 < 10
		ret = ret + '0' + (month+1)
	else
		ret = ret + (month+1)
	if day < 10
		ret = ret + '0' + day
	else
		ret = ret + day
	
	if hour < 10
		ret = hour + '0' + hour
	else
		ret = ret + hour
		
	if min < 10
		ret = min + '0' + min
	else
		ret = ret + min



exports.changeDirectory = changeDirectory = (filenames, destination) ->

	string = false
	if typeof filenames == 'string'
		string = true
		filenames = [filenames]
		
	output = new Array(filenames.length)

	for i in [0...filenames.length]
		output[i] = path.join destination, path.basename filenames[i]
	
	if string
		return output[0]
	else
		return output

exports.changeExtension = changeExtension = (filenames, oldext, newext) ->
	r = new RegExp('\.' + oldext + '$', 'i')
	
	string = false
	if typeof filenames == 'string'
		string = true
		filenames = [filenames]
		
	output = new Array(filenames.length)

	for i in [0...filenames.length]
		if filenames[i].match(r)
			output[i] = filenames[i].replace(r, '.' + newext)
		else
			output[i] = filenames[i] + '.' + newext
	
	if string
		return output[0]
	else
		return output
		

