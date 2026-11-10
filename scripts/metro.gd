extends RefCounted
const Data=preload("res://scripts/metro_data.gd")
static func lines_for(index: int) -> String:
	var names: Array=[]
	for line in Data.LINES:
		if line.stations.has(index) and not names.has(line.name):names.append(line.name)
	return " / ".join(names)
static func neighbors(index: int) -> Array:
	var result: Array=[]
	for line in Data.LINES:
		for i in range(line.stations.size()-1):
			var a=int(line.stations[i])
			var b=int(line.stations[i+1])
			if a==index and not result.has(b):result.append(b)
			if b==index and not result.has(a):result.append(a)
	return result
static func route(from: int,to: int) -> Array:
	if from<0 or to<0 or from>=Data.STATIONS.size() or to>=Data.STATIONS.size():return []
	var queue: Array=[from]
	var parents={from:-1}
	while not queue.is_empty():
		var current: int=queue.pop_front()
		if current==to:break
		for next in neighbors(current):
			if not parents.has(next):
				parents[next]=current
				queue.append(next)
	if not parents.has(to):return []
	var result: Array=[]
	var cursor=to
	while cursor!=-1:
		result.push_front(cursor)
		cursor=parents[cursor]
	return result
static func route_names(from: int,to: int) -> String:
	var result: Array=[]
	for index in route(from,to):result.append(Data.STATIONS[index].name)
	return " → ".join(result)
