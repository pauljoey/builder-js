
cmd_coffee = (sources, output) ->
	"coffee --output #{output} --compile #{sources}"
	
cmd_minify = (sources, output) ->
	"yui-compressor --type js -o #{output}  #{sources}"


shell = require('shelljs')
exports.ls = shell.ls

coffee = require 'coffee-script'
fs	   = require 'fs'
path   = require 'path'
exec   = require('child_process').exec
util   = require 'util'
crypto = require 'crypto'
#mini = 'yui-compressor -o'
try 
	growl = require('growl')
catch err
	growl = (msg) ->
		console.log(msg)


#command = require('common-node').subprocess.command

tsort   = require('./tsort').tsort

dirsep = '/'

uuid4 = (a, b) ->
	b = a = ""
	while a++ < 36
		b += (if a * 51 & 52 then (if a ^ 15 then 8 ^ Math.random() * (if a ^ 20 then 16 else 4) else 4).toString(16) else "-")
	b

# Target: 
#	Name: 'All'
#	Dependencies/Sources: app.js.min
#	Build: Do nothing. Just build dependencies

# Target: 
#	Name: app.js.min
#	Dependencies/Sources: app.js
# 	Build: minimize [sources]

# Target:
#	Name: app.js
#	Dependencies/Sources: [script1.coffee script2.coffee]
#	

# Sources that are not defined as targets are assumes to be files and should exist.
# Targets can be sources

# A "Target" is a special kind of Source/Node that can be built. 


DEBUG = () ->
	if arguments.length == 1 then console.log(arguments[0]) else console.log((i for i in arguments).join(',\t'))

error = () ->
	if arguments.length == 1 then console.error(arguments[0]) else console.error((i for i in arguments).join(',\t'))
	arguments.nice_error = true
	growl arguments[0]
	throw arguments
	
systemerror = () ->
	if arguments.length == 1 then console.error(arguments[0]) else console.error((i for i in arguments).join(',\t'))
	throw arguments
	
warn = () ->
	if arguments.length == 1 then console.warn(arguments[0]) else console.warn((i for i in arguments).join(',\t'))
	
info = () ->
	if arguments.length == 1 then console.info(arguments[0]) else console.info((i for i in arguments).join(',\t'))
	
notify = (message) ->
	growl message
	
	
current_level = 0

levelUp = () ->
	current_level += 1
	
levelDown = () ->
	current_level -= 1
	current_level = 0 if current_level < 0
	
levelReset = () ->
	current_level = 0
	
# When executing a target, build depency list like so from all dependent nodes stemming from target

###
edges = [
    ['test.js', 's1.js'],
    ['test.js', 's2.js'],
    ['all', 'test.js'],
    ['s1.js', 'time.js']
]


console.log(tsort(edges))
###

class ProjectManager
	
	# Hacks
	@first = null
	@last = null
	
	@PROJECTS = {}

	@getProject: (name) ->
		return ProjectManager.PROJECTS[name]
		
	@createProject: (name, options, nodes) ->
		if project = ProjectManager.getProject(project)
			# Set options, add nodes
		else
			project = ProjectManager.PROJECTS[name] = new Project(name, options)
			#p2 = project
			#DEBUG 'Nodes time!'
			#nodes()
		
		unless ProjectManager.last?
			ProjectManager.first = project
			
		ProjectManager.last = project
		return project


class NodeManager

	__unresolved_nodes = null

	#@targets = {}
	@STATUS_UPTODATE = 0
	@STATUS_NEEDSUPDATE = 10
	@STATUS_UPDATING = 20
	
	constructor: (options) ->
		@__unresolved_nodes = {}
	
	createTarget: (name, sources, build_function) ->
		#DEBUG 'NodeManager:createTarget()', 'called args=', JSON.stringify(i for i in arguments)
		if node = @getNode(name)
			if node.is_target == true
				warn 'NodeManager:createTarget()', 'Re-defining target ' + name
		else
			node = @createNode(name)
			
		node.build_function = build_function
		node.is_target = true
		
		for source_name in sources
			# If string, resolve node
			if typeof source_name == 'string'
				source = @createNode(source_name)
			# Otherwise assume it is a node object
			else
				source = source_name
			source.is_source = true
			node.addSource(source)
		
		return node

	getNode: (name) ->
		return @__unresolved_nodes[name]

	getTarget: (name) ->
		return @getNode(name)
		
	getSource: (name) ->
		return @getNode(name)
		
	createNode: (name) ->
		unless node = @__unresolved_nodes[name]
			node = @__unresolved_nodes[name] = new Node(@, name)		
		return node


class Project extends NodeManager
	name = ''
	staging_dir = '=staging/'
	build_dir = '=build/'
	source_dir = './'
	base_dir = './'
	
	@instance = null

	constructor: (name, options) ->
		@name = name
		@setOptions(options) if options?
		super()
		
	setOptions: (options) ->
		@build_dir = options.build_dir if options.build_dir? 
		@staging_dir = options.staging_dir if options.staging_dir? 
		@source_dir = options.source_dir if options.source_dir? 
		@base_dir = options.base_dir if options.base_dir?


class Buffer
	contents = null
	length = 0
	type = 0

	@TYPE_EMPTY = 0
	@TYPE_SOURCE = 10
	@TYPE_FILEPATH = 20
	@TYPE_STRING = 30
	
	@TEMP_FILES = []
	
	constructor: (node) ->
		@node = node
		@clear()


	clear: () ->
		@contents = null
		@length = 0
		@type = Buffer.TYPE_EMPTY


	toString: () ->
		###
		if @type == Buffer.TYPE_SOURCE 
			DEBUG 'Source->String conversion ', @contents
			contents = new Array(@length)
			for source, index in @contents then do (source, index) =>
				f = @node.findSourcePath(source.file)
				contents[index] = fs.readFileSync "#{f}", 'utf8'
			@type = Buffer.TYPE_STRING
			@contents = contents
			return @contents
		###
		if @type == Buffer.TYPE_FILEPATH 
			contents = new Array(@length)
			for data, index in @contents then do (data, index) =>
				DEBUG 'Reading ' + data
				contents[index] = fs.readFileSync "#{data}", 'utf8'
			@type = Buffer.TYPE_STRING
			@contents = contents
			return @contents
		else if @type == Buffer.TYPE_STRING
			return @contents

	toFile: () ->
		###
		if @type == Buffer.TYPE_SOURCE 
			DEBUG 'Source->File conversion ' 
			contents = new Array(@length)
			for source, index in @contents then do (source, index) =>
				contents[index] = @node.findSourcePath(source.file)
			@type = Buffer.TYPE_FILEPATH
			@contents = contents
			return @contents
		###
		if @type == Buffer.TYPE_STRING
			contents = new Array(@length)
			for i in [0...@length]
				filename = @getTempFile()
				fs.writeFileSync filename, @contents[i], 'utf8'
				contents[i] = filename
			@type = Buffer.TYPE_FILEPATH
			@contents = contents
			return @contents
		else if @type == Buffer.TYPE_FILEPATH
			return @contents


	getFile: () ->
		# assume we're built and up to date..

		if @type == Buffer.TYPE_FILEPATH 
			return @contents.slice(0)
			
		else if @type == Buffer.TYPE_STRING
			contents = new Array(@length)
			for i in [0...@length]
				filename = @getTempFile()
				fs.writeFileSync filename, @contents[i], 'utf8'
				contents[i] = filename
			return contents
		else
			warn 'Unknown buffer type'
			return null

	getString: () ->
	
		if @type == Buffer.TYPE_FILEPATH 
			contents = new Array(@length)
			for data, index in @contents then do (data, index) =>
				DEBUG 'Reading ' + data
				contents[index] = fs.readFileSync "#{data}", 'utf8'
			return contents
		else if @type == Buffer.TYPE_STRING
			return @contents.slice(0)
		else
			warn 'Unknown buffer type'
			return null
		
	pop: () ->
		removed = @contents.pop()
		@length = @contents.length
		return removed

	shift: () ->
		removed = @contents.shift()
		@length = @contents.length
		return removed

	getTempFile: (file) ->
		file = path.join @node.project.staging_dir, '~_tmp_' + @node.name.replace(dirsep,'_') + '.' + uuid4()
		# Make sure path exists
		mkdir path.dirname(file)
		Buffer.registerTempFile(file)
		return file

	@registerTempFile: (file) ->
		DEBUG 'Registering temp file ' + file
		Buffer.TEMP_FILES.push(file)
		
	@deleteTempFiles: () ->
		if Buffer.TEMP_FILES.length
			DEBUG 'Deleting temp files... '
			for f in Buffer.TEMP_FILES
				try
					fs.unlinkSync(f)
				catch err
					warn 'Error deleting temp file: ' + err
				
				
		Buffer.TEMP_FILES = []

	

# Status
# 
class Node extends NodeManager
	name = null
	file = null
	sources = null
	targets = null
	buffer = null
	build_function = null
	is_target = null
	is_source = null
	is_building = false
	first_build_completed = false
	is_file_source = false
	is_watched = false
	build_requested = false
	last_modified = 0
	project = null
	last_updated = 0
	depth = 0
	
	constructor: (project, name) ->
		#DEBUG 'Node:New()', 'called args=', JSON.stringify(i for i in arguments)
		@project = project 
		@name = name
		@file = name
		@sources = []
		@targets = []
		@buffer = new Buffer(@)
		@last_modified = 0
		@last_updated = 0
		@depth = 0
		
		# Default build_function action:
		@build_function = @buildFile

	addSource: (source) ->
		@sources.push(source) if @sources.indexOf(source) < 0 
		source.targets.push(@) if source.targets.indexOf(@) < 0 

	buildSources: (options) ->
		@is_building = true
		for source in @sources
			source.build(options)
			
	checkSourceBuilds: (options) ->
		if @build_requested
			#DEBUG 'checkSourceBuilds() ' + @name 
			for source in @sources
				if source.is_building or ! source.first_build_completed
					return
			@buildSelf(options)
			
		return
	
	
	watch: () ->
		@build({watch: true})
	
	build: (options) ->
		#DEBUG 'Node:build()', 'called args=', JSON.stringify(i for i in arguments)
		@build_requested = true

		# If the target has sources, build them.
		# They will trigger the building of the target as 
		# they complete by calling checkSourceBuilds()
		if 0 < @sources.length 
			info 'Building dependencies ' + @name
			@buildSources(options)
		else
			@buildSelf(options)
	
	buildSelf: (options) ->


		if @first_build_completed 
			#DEBUG 'buildSelf() ' + @name + ' ' + new Date(@last_modified)
			stale = false
			for source in @sources
				if @last_modified < source.last_modified
					#DEBUG 'newer ' + source.name + ' ' + new Date(source.last_modified)
					stale = true
					break
				else
					#DEBUG 'older ' + source.name + ' ' + new Date(source.last_modified)
		else
			stale = true


		unless stale
			info 'Up to date ' + @name
		else
			info 'Building ' + @name
			if @build_function
				#DEBUG 'buildSelf()', 'calling build_function'
				# Fork here and wait until build_function is done
				@is_building = true
				#if @sources
				#	@buffer = new Buffer(@sources, @project.staging_dir)
				@start(options)
				@build_function(options)
				# Serial execution
				@done(options)
			else
				#DEBUG 'buildSelf()', 'no build_function'   
				@is_building = false
				#if @sources
				#	@buffer = new Buffer(@sources, @project.staging_dir)
				@start(options)
				@done(options)
				
	###				
	getFile: () ->
		unless @first_build_completed
			@build()
		return @findSourcePath(@file)

		
	getContents: () ->
		unless @first_build_completed
			@build()
		p = @findSourcePath(@file)
		contents = fs.readFileSync p, 'utf8'
		return contents
	###
	
	# Copy sources into buffer	
	start: (options) ->
		@buffer.clear()
		
		# May make this an explicit build command?
		# @buffer.contents = @sources
		# @buffer.length = @sources.length
		# @buffer.type = Buffer.TYPE_SOURCE
		
	done: (options) ->
		@first_build_completed = true
		@is_building = false
		unless @is_file_source
			@last_modified = (new Date()).getTime()
		
		# Copy self into buffer if we have no sources or rule - ie, a leaf node
		# ... I think this makes sense to do ...
		#if @sources.length < 1
		#	@buffer = @
		DEBUG 'Done ' + @name
		# Tell parents that we're done building
		for target in @targets
			target.checkSourceBuilds(options)
	
	findSourcePath: (rel_path) ->
		dirs = [@project.source_dir, @project.staging_dir, @project.build_dir, @project.base_dir, '.']

		for d in dirs
			p = path.normalize path.join d, rel_path
			if path.existsSync p
				return p
		
		warn 'Could not locate source ' + rel_path		
		return rel_path

	
	getFile: () ->
		# assume we're built and up to date..
		return @buffer.getFile()


	getString: () ->
		# assume we're built and up to date..
		return @buffer.getString()

			
				
	buildFile: (options) ->

		# resolve path
			
		p = @findSourcePath(@name)
		DEBUG 'Found file/target ' + p
		@is_file_source = true
		
		try
			stats = fs.statSync(p)
		catch err
			error "No target/file named '#{@name}'"
			
		@last_modified = (new Date(stats.mtime)).getTime()
		
		@file = p
		@buffer.type = Buffer.TYPE_FILEPATH 
		@buffer.contents = [p]
		@buffer.length = 1
		
		if options? and options.watch? and options.watch and ! @is_watched
			info 'watching ' + p
			fs.watchFile(p, (curr, prev) => @fileChanged(options, curr, prev)) 
				
	fileChanged: (options, curr, prev) ->

		@last_modified = (new Date(curr.mtime)).getTime()
		info '--> ' + @name + ' changed. ' + new Date(@last_modified)
			
		@first_build_completed = true
		@is_building = false
		
		# Catch errors to ensure compilation continues
		try
			# Tell parents that we're done building
			for target in @targets
				target.checkSourceBuilds(options)	
		catch err
			try
				error err
			catch err
				donothing = true
		
		# This may break things...		
		Buffer.deleteTempFiles()

# Want to be able to 'map' targets.
# ie, 'jquery' -> '/src/vendor/jquery/jquery.js'
#
# This will be important for linked packages
# Perhaps need a 'Package' declaration? Thus all targets become package-specific.
#
# Probably going to need a dependency tree of some kind for asynchronous building...

# May wish to chain targets... as in.. target becomes source for following entry.
# Typical chain
# All -> app.min.js -> (minify) app.js -> (coffee2js) app.coffee -> (cat) file1.coffee, file2.coffee

# How to distinguish build ->
#	@cat <- operates on sources
#	@coffee2js <-- operates on output

Target = Node


Target::getTarget = (name) ->
	s = @project.getTarget(name)
	unless s?  
		warn 'Target not found: ' + name
	return s

			
Target::options = (options) ->
	for key, val of options
		@options[key] = val
		
Target::files = (targets) ->

	# NOTE: need to clone array so that we can modify it without modifying the sources.
	#@buffer.contents = @sources.slice(0)
	#@buffer.length = @sources.length
	#@buffer.type = Buffer.TYPE_SOURCE
	
	if sources? and sources
		# If sources is a string, assume it is a named target. Resolve it.
		if typeof sources == 'string'
			s = @project.getTarget(sources)
			unless s?
				error 'Source not found: ' + sources
			sources = [s]
		# Otherwise assume it's an array
		else
			for i in [0...sources.length]
				# See if any items in the sources array are named targets (strings)
				# and resolve them if they are.
				if typeof sources[i] == 'string'
					s = @project.getTarget(sources[i])
					unless s?
						error 'Source not found: ' + sources[i]
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
				error 'Source not found: ' + sources
			sources = [s]
		# Otherwise assume it's an array
		else
			for i in [0...sources.length]
				# See if any items in the sources array are named targets (strings)
				# and resolve them if they are.
				if typeof sources[i] == 'string'
					s = @project.getTarget(sources[i])
					unless s?
						error 'Source not found: ' + sources[i]
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


# Writes buffer contents to output directory (using target name as the filename)
Target::write = (filenames) ->
	
	@buffer.toString()
	
	if filenames? and filenames
		if typeof filenames == 'string'
			filenames = [filenames]
	else
		filenames = [@name]
	
	if @buffer.length < 1
		error 'Cannot write files -- nothing to write!'
	
	unless @buffer.length == filenames.length
		error 'Cannot write files -- buffer length and filenames are different sizes'
	
	#if @buffer.length == 1 and typeof @buffer.contents == 'string'
	#	contents = [@buffer.contents]
	#else
	#	contents = @buffer.contents
	
	for i in [0...@buffer.length]
	
		loc = path.join @project.build_dir, filenames[i]
	
		# Make sure directory exists
		mkdir path.dirname loc
	
		fs.writeFileSync loc, @buffer.contents[i], 'utf8'
			
		info "Writing #{loc}"
	
# Writes buffer contents to staging directory (using target name as the filename)
Target::writeTmp = (filenames) ->
	
	@buffer.toString()
	
	if filenames? and filenames
		if typeof filenames == 'string'
			filenames = [filenames]
	else
		filenames = [@name]
	
	if @buffer.length < 1
		error 'Cannot write files -- nothing to write!'
		
	unless @buffer.length == filenames.length
		error 'Cannot write files -- buffer length and filenames are different sizes'
		
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
	###
	@buffer.toFile()
	
	for i in [0...@buffer.length]
		file = @buffer.contents[i]
		file_out = changeExtension(file, 'coffee','js')
		file_out = path.join @project.staging_dir, file_out
		
		DEBUG 'here ', file, file_out
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



Target::replace = (match, replace) ->

	@buffer.toString()
	
	for i in [0...@buffer.length]
		c = @buffer.contents[i]
		c = c.replace(match, replace)
		@buffer.contents[i] = c
		
Target::minify = (filenames) ->
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
		error 'Cannot write files -- buffer length and filenames are different sizes'
	
	for i in [0...@buffer.length]
		out_file = filenames[i]
		result = shell.exec cmd_minify(@buffer.contents[i], out_file)
		info "Minified #{@buffer.contents[i]}"
		@buffer.contents[i] = out_file
		


Target::appendFile = (file) ->

	@buffer.toString()
	
	info "Append " + file
	
	file = @findSourcePath(file)
	
	contents = fs.readFileSync file, 'utf8'
	unless contents
		error 'Could not read file ' + file
		
	for i in [0...@buffer.length]
		@buffer.contents[i] = @buffer.contents[i] + '\n' + contents

Target::prependFile = (file) ->

	@buffer.toString()
	
	info "Prepend " + file
	
	file = @findSourcePath(file)
	
	contents = fs.readFileSync file, 'utf8'
	unless contents
		error 'Could not read file ' + file
		
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
		checksums[i] = sha256(@buffer.contents[i])
		
	return checksums
	

sha256 = (data) ->
	return crypto.createHash('sha256').update(data).digest("hex")
exports.sha256 = sha256

changeDirectory = (filenames, destination) ->

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

changeExtension = (filenames, oldext, newext) ->
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
		

		
timestamp = (time) ->

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

mkdir = (p, mode) ->
	p = path.normalize(p)
	# Quick check and return
	if path.existsSync(p)
		return true

	parts = p.split(dirsep)
	# Search backward to find first non-missing directory.
	dirs = parts.length
	pos = dirs
	missing_pos = 1
	while 0 < pos
		if path.existsSync(parts[0...pos].join(dirsep))
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
		
exports.mkdir = mkdir

run = (target, project, options) ->
	target ?= 'build' 
	project ?= ProjectManager.last
	options ?= {}
	
	try
		t = project.getTarget(target)
		unless t?
			error "No target named '#{target}'"	
		else
			DEBUG 'Running...'
			t.build(options)
			Buffer.deleteTempFiles()
	catch err
		unless err.nice_error? and err.nice_error
			Buffer.deleteTempFiles()
			throw err

exports.run = run

watch = (target, project, options) ->
	options ?= {watch: true}
	options.watch ?= true
	return run(target, project, options)

exports.watch = watch

importProject = (project_path) ->
	project_path = fs.realpathSync project_path
	coffee.run fs.readFileSync(path.join(project_path, 'Cakefile')).toString(), filename: 'Cakefile'
	# KLUDGE
	prj = ProjectManager.last
	
	# Remap source directories	
	prj.base_dir = path.resolve(project_path, prj.base_dir)
	prj.source_dir = path.resolve(project_path, prj.source_dir)
	prj.build_dir = path.resolve(project_path, prj.build_dir)
	prj.staging_dir = path.resolve(project_path, prj.staging_dir)
	
	return prj


exports.importProject = importProject

###
target = (name, sources, build_function) ->
	if Project.instance
		project = Project.instance
	else 
		project = Project.instance = new Project()
	return NodeManager.createTarget(project, name, sources, build_function)

project = (options) ->
	if Project.instance
		Project.instance.setOptions(options)
		return Project.instance
	else
		return Project.instance = new Project(options)
###

target = (name, sources, build_function) ->
	project = ProjectManager.last
	unless project
		error 'No project declared'
	else 
		return project.createTarget(name, sources, build_function)

project = ProjectManager.createProject


exports.debug = DEBUG
exports.info = info
exports.warn = warn
exports.error = error
exports.notify = notify

exports.changeExtension = changeExtension
exports.changeDirectory = changeDirectory
exports.shell = shell

exports.lastProject = -> return ProjectManager.last
exports.firstProject = -> return ProjectManager.first
exports.getProject = (name) -> return ProjectManager.getProject(name)

exports.target = target
exports.project = project

