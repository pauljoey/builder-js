
cmd_coffee = (sources, output) ->
	"coffee --output #{output} --compile #{sources}"
	
cmd_minify = (sources, output) ->
	"yui-compressor  -o #{output}  #{sources}"

fs	 = require 'fs'
{exec} = require 'child_process'
util   = require 'util'
#mini = 'yui-compressor -o'

tsort   = (require './tsort').tsort

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
	
info = () ->
	if arguments.length == 1 then console.info(arguments[0]) else console.info((i for i in arguments).join(',\t'))
	
# When executing a target, build depency list like so from all dependent nodes stemming from target
edges = [
    ['test.js', 's1.js'],
    ['test.js', 's2.js'],
    ['all', 'test.js'],
    ['s1.js', 'time.js']
]


console.log(tsort(edges))


class Source
	file = null
	dependencies = null
	
	@sources = {}
		
	@create: (file, target) ->
		DEBUG 'Source:create()', 'called args=', JSON.stringify(i for i in arguments)
		if source = Source.get(file)
			DEBUG 'Source:create()', ''
			source.addTarget(target)
		else
			source = new Source(file, target)
			
		return source

	constructor: (file, target) ->
		DEBUG 'Source:constructor()', 'called args=', JSON.stringify(i for i in arguments)
		Source.sources[file] = @
		@file = file
		@targets = [target]
		super()

	###
	Function: get
		Retrieve the Source() object for the given file
	Parameters:
		file - The path to the source file.
	Returns:
		The existing Source() object associated with the file
	###
	@get: (file) ->
		return Source.sources[file]

	###
	Function: addTarget
		Retrieve the Source() object for the given file
	Parameters:
		file - The path to the source file.
	Returns:
		The existing Source() object associated with the file
	###
	addTarget: (target) ->
		@targets.push(target)



class Target extends Source
	# Class method. Mapping of all Target names to objects
	@targets = {}
	
	# Array of dependent sources (Source objects)
	sources = null

	constructor: (name, sources, buildFunction) ->
		DEBUG 'Target:constructor()', 'called args=', JSON.stringify(i for i in arguments)
		@name = name
		Target.targets[name] = @
		@sources = []
		for source in sources
			@addSource(source)
		@buildFunction = buildFunction
		#@buildFunction()
		@options = {}
		super()
		
	build: () ->
		DEBUG 'Target:build()', 'called args=', JSON.stringify(i for i in arguments)
		for source in @sources
			# For each dependent source, see if a corresponding target is defined.
			# If it is, build it.
			if dependent_target = Target.get(source.file)
				dependent_target.build()
		if @buildFunction
			DEBUG 'Target:build()', 'calling buildFunction'
			@buildFunction()
		
	@get: (target_name) ->
		return Target.targets[target_name]
		
	addSource: (source) ->
		@sources.push(Source.create(source, @))

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
	
			
Target::options = (options) ->
	for key, val of options
		@options[key] = val


Target::cat = () ->

	remaining = @sources.length
	contents = new Array(remaining)
	
	for file, index in @sources then do (file, index) ->
		fs.readFile file, 'utf8', (err, fileContents) ->
			error(err) if err
			
			contents[index] = fileContents
			process() if --remaining is 0

	process = ->
		fs.writeFile @name, contents.join('\n'), 'utf8', (err) ->
			if err
				error("cat #{@name} failed: " + err) 
			else
				info "Concatenated #{@name}"
			

Target::coffee2js = () ->
	exec cmd_coffee(@sources, @name), (err, stdout, stderr) ->
		if err
			error("coffee #{@name} failed: " + err) 
		else
			info "Compiled #{@name}"
		
		
Target::minify = () ->
	exec cmd_minify(@sources, @name), (err, stdout, stderr) -> 
		if err
			error("Minify #{@name} failed: " + err) 
		else
			info "Minified #{@name}"

Target::appendFile = (file) ->
	appendFileContents = fs.readFileSync file, 'utf8'
	unless appendFileContents
		error 'Could not read file ' + file
		
	fileContents = fs.readFileSync @name, 'utf8'
	unless fileContents
		error 'Could not read file ' + @name
		
	bytesWritten = fs.writeFileSync @name, 'utf8', fileContents + '\n' + appendFileContents
	unless bytesWritten
		error 'Could not write file ' + @name

Target::prependFile = (file) ->
	appendFileContents = fs.readFileSync file, 'utf8'
	unless appendFileContents
		error 'Could not read file ' + file
		
	fileContents = fs.readFileSync @name, 'utf8'
	unless fileContents
		error 'Could not read file ' + @name
		
	bytesWritten = fs.writeFileSync @name, 'utf8', fileContents + '\n' + appendFileContents
	unless bytesWritten
		error 'Could not write file ' + @name


Target::append = (append_string) ->
	fileContents = fs.readFileSync @name, 'utf8'
	unless fileContents
		error 'Could not read file ' + @name
		
	bytesWritten = fs.writeFileSync @name, 'utf8', fileContents + append_string
	unless bytesWritten
		error 'Could not write file ' + @name
		

Target::prepend = (prepend_string) ->
	fileContents = fs.readFileSync @name, 'utf8'
	unless fileContents
		error 'Could not read file ' + @name
		
	bytesWritten = fs.writeFileSync @name, 'utf8', prepend_string + fileContents
	unless bytesWritten
		error 'Could not write file ' + @name

	
	
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
		ret = ret +  day
	
	if hour < 10
		ret = hour + '0' + hour
	else
		ret = ret + hour
		
	if min < 10
		ret = min + '0' + min
	else
		ret = ret + min
	

Target_func = (name, sources, buildFunction) ->
	return new Target(name, sources, buildFunction)

#exports.Target = Target
exports.Target = Target_func


