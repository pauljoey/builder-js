file1 = 'Great'

execAsync = (cmd) ->
	return asyncblock (flow) ->
		DEBUG 'exec running'
		exec cmd, (err, stdout, stderr) -> 
			DEBUG 'exec ' + cmd + ' complete'
			flow.add()
		DEBUG 'exec waiting'
		result = flow.wait()
		DEBUG 'exec returning'
		return result 
