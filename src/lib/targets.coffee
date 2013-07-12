

shell  = require('shelljs')
exports.ls = shell.ls

coffee = require 'coffee-script'
less   = require 'less'
fs     = require 'fs'
path   = require 'path'
exec   = require('child_process').exec
#crypto = require 'crypto'



base    = require('./base')
Buffer  = base.Buffer
Node    = base.Node

util    = require './util'

error   = util.error
warn    = util.warn
info    = util.info
debug   = util.debug

notify  = util.notify
abort   = util.abort

mkdir   = util.mkdir

### These are core rules ###

cmd_less = (sources, output) ->
	"lessc #{sources} > #{output}"

cmd_coffee = (sources, output) ->
	"coffee --output #{output} --compile #{sources}"
	
cmd_minify_js = (sources, output) ->
	"uglifyjs -o #{output}  #{sources}"

cmd_minify_css = (sources, output) ->
	"yui-compressor --type css -o #{output}  #{sources}"



Target = Node


Target::getTarget = (name) ->
	s = @project.getTarget(name)
	unless s?  
		warn 'Target not found: ' + name
	return s
	

Target::options = (options) ->
	for key, val of options
		@options[key] = val
		
Target::files = (sources) ->

	# NOTE: need to clone array so that we can modify it without modifying the sources.
	#@buffer.contents = @sources.slice(0)
	#@buffer.length = @sources.length
	#@buffer.type = Buffer.TYPE_SOURCE
	
	if sources? and sources
		# If sources is a string, assume it is a named target. Resolve it.
		if typeof sources == 'string'
			s = @project.getTarget(sources)
			unless s?
				abort 'Source not found: ' + sources
			sources = [s]
		# Otherwise assume it's an array
		else
			for i in [0...sources.length]
				# See if any items in the sources array are named targets (strings)
				# and resolve them if they are.
				if typeof sources[i] == 'string'
					s = @project.getTarget(sources[i])
					unless s?
						abort 'Source not found: ' + sources[i]
					sources[i] = s
	else
		sources = @sources
	
	@buffer.contents = []
	for i in [0...sources.length]
		source_files = sources[i].getFile()
		for f in source_files
			@buffer.contents.push(f)
	@buffer.length = @buffer.contents.length
	@buffer.type = Buffer.TYPE_FILEPATH

Target::read = (sources) ->

	# NOTE: need to clone array so that we can modify it without modifying the sources.
	#@buffer.contents = @sources.slice(0)
	#@buffer.length = @sources.length
	#@buffer.type = Buffer.TYPE_SOURCE
	
	if sources? and sources
		# If sources is a string, assume it is a named target. Resolve it.
		if typeof sources == 'string'
			s = @project.getTarget(sources)
			unless s?
				# Could be a new file. If so, add it as a source and build it
				s = @project.createNode(sources)
				s.build()
				#abort 'Source not found: ' + sources
			sources = [s]
		# Otherwise assume it's an array
		else
			for i in [0...sources.length]
				# See if any items in the sources array are named targets (strings)
				# and resolve them if they are.
				if typeof sources[i] == 'string'
					s = @project.getTarget(sources[i])
					unless s?
						#abort 'Source not found: ' + sources[i]
						# Could be a new file. If so, add it as a source and build it
						s = @project.createNode(sources[i])
						s.build()
					sources[i] = s
	else
		sources = @sources
	
	@buffer.contents = []
	for i in [0...sources.length]
		files = sources[i].getString()
		for f in files
			@buffer.contents.push(f)
	@buffer.length = @buffer.contents.length
	@buffer.type = Buffer.TYPE_STRING



Target::pop = () ->

	@buffer.pop()


Target::shift = () ->

	@buffer.shift()


Target::cat = () ->
	
	@buffer.toString()
	
	if 1 < @buffer.length
		@buffer.contents = [@buffer.contents.join('\n')]
		@buffer.length = 1
	
	info "Concatenated files"
	
	
Target::find = (pattern) ->
	
	@buffer.toString()
	
	contents = @buffer.contents.join('\n')
	
	return contents.match(pattern)


# Writes buffer contents to output directory (using target name as the filename)
Target::write = (filenames) ->
	
	@buffer.toString()
	
	if filenames? and filenames
		if typeof filenames == 'string'
			filenames = [filenames]
	else
		filenames = [@name]
	
	if @buffer.length < 1
		abort 'Cannot write files -- nothing to write!'
	
	unless @buffer.length == filenames.length
		abort 'Cannot write files -- buffer length and filenames are different sizes'
	
	#if @buffer.length == 1 and typeof @buffer.contents == 'string'
	#	contents = [@buffer.contents]
	#else
	#	contents = @buffer.contents
	
	for i in [0...@buffer.length]
	
		loc = path.join @project.build_dir, filenames[i]
	
		# Make sure directory exists
		#mkdir path.dirname loc
		shell.mkdir('-p', path.dirname loc)
	
		fs.writeFileSync loc, @buffer.contents[i], 'utf8'
			
		info "Writing #{loc}"



Target::copyTo = (loc) ->

	loc ?= @name
	loc = path.join @project.build_dir, loc

	@buffer.toFile()
	
	shell.mkdir('-p', loc)
	shell.cp('-fR', @buffer.contents, loc)
	
	info "Copying #{@name} to #{loc}"

Target::copyToTmp = (loc) ->

	loc ?= @name
	loc = path.join @project.staging_dir, loc

	in_files = @buffer.toFile()
	
	shell.mkdir('-p', loc)
	shell.cp('-fR', @buffer.contents, loc)
	
	info "Copying #{@name} to #{loc}"

	
# Writes buffer contents to staging directory (using target name as the filename)
Target::writeTmp = (filenames) ->
	
	@buffer.toString()
	
	if filenames? and filenames
		if typeof filenames == 'string'
			filenames = [filenames]
	else
		filenames = [@name]
	
	if @buffer.length < 1
		abort 'Cannot write files -- nothing to write!'
		
	unless @buffer.length == filenames.length
		abort 'Cannot write files -- buffer length and filenames are different sizes'
		
	#if @buffer.length == 1 and typeof @buffer.contents == 'string'
	#	contents = [@buffer.contents]
	#else
	#	contents = @buffer.contents
		
	for i in [0...@buffer.length]
	
		loc = path.join @project.staging_dir, filenames[i]
	
		# Make sure directory exists
		mkdir path.dirname loc
	
		fs.writeFileSync loc, @buffer.contents[i], 'utf8'
			
		info "Writing #{loc}"
	

Target::coffee2js = () ->

	info 'Converting cs2js'

	###
	@buffer.toFile()
	
	for i in [0...@buffer.length]
		file = @buffer.contents[i]
		file_out = changeExtension(file, 'coffee','js')
		file_out = path.join @project.staging_dir, file_out
		
		debug 'here ', file, file_out
		exec cmd_coffee(file, file_out), (err, stdout, stderr) ->
			if err
				error("coffee #{file} failed: " + err) 
			else
				info "Compiled #{file} to #{file_out}"
	###
	
	@buffer.toString()

	for i in [0...@buffer.length]
		c = @buffer.contents[i]
		try
			compiled = coffee.compile(c)
		catch err
			throw "Error compiling target #{@name} to coffeescript: #{err}"
		
		@buffer.contents[i] = compiled



Target::less2css = () ->
	@buffer.toString()

	for i in [0...@buffer.length]
		c = @buffer.contents[i]
		try
			compiled = coffee.compile(c)
		catch err
			throw "less2css(): Error compiling target #{@name} to css : #{err}"
		
		@buffer.contents[i] = compiled
		
	###
	@buffer.toFile()
	
	if filenames? and filenames
		if typeof filenames == 'string'
			filenames = [filenames]
		
		for i in [0...filenames.length]
			filenames[i] = path.join @project.build_dir, filenames[i]
	else
		filenames = new Array(@buffer.length)
		for i in [0...@buffer.length]
			filenames[i] = @buffer.getTempFile()
		
	unless @buffer.length == filenames.length
		abort 'Cannot write files -- buffer length and filenames are different sizes'
	
	for i in [0...@buffer.length]
		out_file = filenames[i]
		result = shell.exec cmd_less(@buffer.contents[i], out_file)
		info "Compiled LESS file #{@buffer.contents[i]}"
		@buffer.contents[i] = out_file
	###

Target::replace = (match, replace) ->

	@buffer.toString()
	
	for i in [0...@buffer.length]
		c = @buffer.contents[i]
		c = c.replace(match, replace)
		@buffer.contents[i] = c
		
Target::minifyJS = (filenames) ->
	# Here, `filenames` is one or more filenames to use as output files
	# after minification... I think it would be more appropriate
	# to call @write(filenames) after @minifyJS().
	
	info 'Minifying JS'
	
	@buffer.toFile()
	
	if filenames? and filenames
		if typeof filenames == 'string'
			filenames = [filenames]
		
		for i in [0...filenames.length]
			filenames[i] = path.join @project.build_dir, filenames[i]
	else
		filenames = new Array(@buffer.length)
		for i in [0...@buffer.length]
			filenames[i] = @buffer.getTempFile()
		
	unless @buffer.length == filenames.length
		abort 'Cannot write files -- buffer length and filenames are different sizes'
	
	for i in [0...@buffer.length]
		out_file = filenames[i]
		result = shell.exec cmd_minify_js(@buffer.contents[i], out_file)
		info "Minified #{@buffer.contents[i]}"
		@buffer.contents[i] = out_file
		
Target::minifyCSS = (filenames) ->
	# Here, `filenames` is one or more filenames to use as output files
	# after minification... I think it would be more appropriate
	# to call @write(filenames) after @minifyCSS().
	
	info 'Minifying CSS'
	
	@buffer.toFile()
	
	if filenames? and filenames
		if typeof filenames == 'string'
			filenames = [filenames]
		
		for i in [0...filenames.length]
			filenames[i] = path.join @project.build_dir, filenames[i]
	else
		filenames = new Array(@buffer.length)
		for i in [0...@buffer.length]
			filenames[i] = @buffer.getTempFile()
		
	unless @buffer.length == filenames.length
		abort 'Cannot write files -- buffer length and filenames are different sizes'
	
	for i in [0...@buffer.length]
		out_file = filenames[i]
		result = shell.exec cmd_minify_css(@buffer.contents[i], out_file)
		info "Minified #{@buffer.contents[i]}"
		@buffer.contents[i] = out_file
		

Target::appendFile = (file) ->

	@buffer.toString()
	
	info "Appending " + file
	
	file = @findSourcePath(file)
	
	contents = fs.readFileSync file, 'utf8'
	unless contents
		abort 'Could not read file ' + file
		
	for i in [0...@buffer.length]
		@buffer.contents[i] = @buffer.contents[i] + '\n' + contents

Target::prependFile = (file) ->

	@buffer.toString()
	
	info "Prepending " + file
	
	file = @findSourcePath(file)
	
	contents = fs.readFileSync file, 'utf8'
	unless contents
		abort 'Could not read file ' + file
		
	for i in [0...@buffer.length]
		@buffer.contents[i] = contents + '\n' + @buffer.contents[i]
			
		
Target::append = (append_string) ->
		
	@buffer.toString()
	
	for i in [0...@buffer.length]
		@buffer.contents[i] = @buffer.contents[i] + '\n' + append_string
		

Target::prepend = (prepend_string) ->
			
	@buffer.toString()
	
	for i in [0...@buffer.length]
		@buffer.contents[i] = prepend_string + '\n' + @buffer.contents[i]


Target::sha256 = () ->
			
	@buffer.toString()
	
	checksums = new Array(@buffer.length)
	
	for i in [0...@buffer.length]
		checksums[i] = util.sha256(@buffer.contents[i])
		
	return checksums
	

exports.Target = Target

