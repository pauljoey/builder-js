
###
Copyright 2012 Shin Suzuki<shinout310@gmail.com>

	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at

		http://www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.
###

#
# general topological sort
# @author SHIN Suzuki (shinout310@gmail.com)
# @param Array<Array> edges : list of edges. each edge forms Array<ID,ID> e.g. [12 , 3]
#
# @returns Array : topological sorted list of IDs
#

tsort = (edges) ->
	nodes = {}
	sorted = []
	visited = {}
	Node = (id) ->
		@id = id
		@afters = []
		return @

	edges.forEach (v) ->
		from = v[0]
		to = v[1]
		nodes[from] = new Node(from) unless nodes[from]
		nodes[to] = new Node(to) unless nodes[to]
		nodes[from].afters.push to

	Object.keys(nodes).forEach visit = (idstr, ancestors) ->
		node = nodes[idstr]
		id = node.id
		return	if visited[idstr]
		ancestors = []	unless Array.isArray(ancestors)
		ancestors.push id
		visited[idstr] = true
		node.afters.forEach (afterID) ->
			throw new Error("closed chain : " + afterID + " is in " + id)	if ancestors.indexOf(afterID) >= 0
			visit afterID.toString(), ancestors.map((v) ->
				v
			)

		sorted.unshift id

	return sorted
	
module.exports.tsort = tsort if module
