path   = require 'path'
fs     = require 'fs'


base    = require './base'
util    = require './util'
builder = require './builder'

error   = util.error
warn    = util.warn
info    = util.info
debug   = util.debug

notify  = util.notify
abort   = util.abort


Buffer = base.Buffer

exports.run = run = (target, project, options) ->
	target ?= 'build' 
	project ?= base.activeProject()
	options ?= {}
	
	try
		t = project.getTarget(target)
		unless t?
			abort "No target named '#{target}'"
		else
			debug 'Running...'
			t.build(options)
			Buffer.deleteTempFiles()
	catch app_error
		unless app_error.handled_error? and app_error.handled_error
			Buffer.deleteTempFiles()
			error "An unexpected error occured building target '#{target}'. Aborting."
			throw app_error


exports.watch = watch = (target, project, options) ->
	options ?= {watch: true}
	options.watch ?= true
	return run(target, project, options)



exports.importProject = (project_path) ->
	project_path = fs.realpathSync project_path
	coffee.run fs.readFileSync(path.join(project_path, 'Builderfile')).toString(), filename: 'Builderfile'
	
	# KLUDGE
	prj = base.activeProject()
	
	# Remap source directories	
	prj.base_dir = path.resolve(project_path, prj.base_dir)
	prj.source_dir = path.resolve(project_path, prj.source_dir)
	prj.build_dir = path.resolve(project_path, prj.build_dir)
	prj.staging_dir = path.resolve(project_path, prj.staging_dir)
	
	return prj


# `builder` is a simplified version of [Make](http://www.gnu.org/software/make/)
# ([Rake](http://rake.rubyforge.org/), [Jake](http://github.com/280north/jake))
# for CoffeeScript. You define tasks with names and descriptions in a Cakefile,
# and can call them from the command line, or invoke them from other tasks.
#
# Running `cake` with no arguments will print out a list of all the tasks in the
# current directory's Cakefile.

# External dependencies.
fs           = require 'fs'
path         = require 'path'

optparse     = require './optparse'
coffee       = require 'coffee-script'

existsSync   = fs.existsSync or path.existsSync

# Keep track of the list of defined tasks, the accepted options, and so on.
targets   = {}
options   = {}
switches  = [  
	['-w', '--watch',      'watch sources for changes and re-build targets']
]
oparse    = null

global.target = base.target
global.project = base.project
global.builder = builder


# Run `builder`. Executes all of the tasks you pass, in order. Note that Node's
# asynchrony may cause tasks to execute in a different order than you'd expect.
# If no tasks are passed, print the help screen. Keep a reference to the
# original directory name, when running Cake tasks from subdirectories.
exports.runBuilderFile = ->
	global.__originalDirname = fs.realpathSync '.'
	process.chdir builderfileDirectory(__originalDirname)
	args = process.argv[2..]
	coffee.run fs.readFileSync('Builderfile').toString(), filename: 'Builderfile'
	oparse = new optparse.OptionParser switches
	return printTargets() unless args.length
	try
		options = oparse.parse(args)
	catch e
		return fatalError "#{e}"
	
	
	project = base.activeProject()
	
	unless project
		abort "#{builderfilePath} does not define a project"
	
	if options and options.watch
		watch(arg, project) for arg in options.arguments
	else
		run(arg, project) for arg in options.arguments
	
	

# Display the list of Builder tasks in a format similar to `rake -T`
printTargets = ->
	relative = path.relative or path.resolve
	builderfilePath = path.join relative(__originalDirname, process.cwd()), 'Builderfile'
	project = base.activeProject()
	unless project
		abort "#{builderfilePath} does not define a project"
	console.log "#{builderfilePath} defines the following targets:\n"
	targets = project.getTargets()
	for name, target of targets
		spaces = 20 - name.length
		spaces = if spaces > 0 then Array(spaces + 1).join(' ') else ''
		#desc   = if target.description then "# #{target.description}" else ''
		#console.log "builder #{name}#{spaces} #{desc}"
		console.log "builder #{name}"
	console.log oparse.help() if switches.length

# Print an error and exit when attempting to use an invalid task/option.
fatalError = (message) ->
	console.error message + '\n'
	console.log 'To see a list of all targets/options, run "builder"'
	process.exit 1

missingTarget = (target) -> fatalError "No such target: #{target}"

# When `builder` is invoked, search in the current and all parent directories
# to find the relevant Builderfile.
builderfileDirectory = (dir) ->
	return dir if existsSync path.join dir, 'Builderfile'
	parent = path.normalize path.join dir, '..'
	return builderfileDirectory(parent) unless parent is dir
	throw new Error "Builderfile not found in #{process.cwd()}"

