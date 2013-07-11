
fs     = require 'fs'
path   = require 'path'

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

exports.mkdir = mkdir = (p, mode) ->
	p = path.normalize(p)
	
	# Quick check and return
	if exists(p)
		return true

	parts = p.split(dirsep)
	# Search backward to find first non-missing directory.
	dirs = parts.length
	pos = dirs
	missing_pos = 1
	while 0 < pos
		if exists(parts[0...pos].join(dirsep))
			missing_pos = pos + 1
			break
		else
		pos -= 1

	# Create directories recursively from there.
	pos = missing_pos
	while pos <= dirs
		info 'mkdir() Creating ' + parts[0...pos].join(dirsep)
		fs.mkdirSync parts[0...pos].join(dirsep)
		pos += 1
		


