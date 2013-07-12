path   = require 'path'
fs     = require 'fs'


base   = require './base'


util    = require './util'

error   = util.error
warn    = util.warn
info    = util.info
debug   = util.debug

notify  = util.notify
abort   = util.abort


ProjectManager = base.ProjectManager
Buffer = base.Buffer

exports.run = run = (target, project, options) ->
	target ?= 'build' 
	project ?= ProjectManager.last
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



exports.importProject = importProject = (project_path) ->
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



