class_name ComponentFinder
extends Object

## Shared convention for discovering components without hardcoding node paths.
## We treat a component as "owned by the entity" if it is:
## - a direct child of the entity, OR
## - a child of the conventional `Components/` container.
static func find_component_in_group(entity: Node, group_name: StringName) -> Node:
	if entity == null:
		return null

	for child in entity.get_children():
		if child is Node and (child as Node).is_in_group(group_name):
			return child as Node

	var components := entity.get_node_or_null(NodePath("Components"))
	if components is Node:
		for child in (components as Node).get_children():
			if child is Node and (child as Node).is_in_group(group_name):
				return child as Node

	return null

static func find_components_in_group(
	entity: Node,
	group_name: StringName,
	include_self: bool = true
) -> Array[Node]:
	## Returns all "owned" components on an entity:
	## - the entity itself (optional), if it's in the group
	## - direct children of the entity that are in the group
	## - children of the conventional `Components/` container that are in the group
	var out: Array[Node] = []
	if entity == null:
		return out

	if include_self and entity.is_in_group(group_name):
		out.append(entity)

	for child in entity.get_children():
		if child is Node and (child as Node).is_in_group(group_name):
			out.append(child as Node)

	var components := entity.get_node_or_null(NodePath("Components"))
	if components is Node:
		for child in (components as Node).get_children():
			if child is Node and (child as Node).is_in_group(group_name):
				out.append(child as Node)

	return out


