class_name ResourceAttribution extends Resource

@export var resource: Resource
@export var original_name: String
@export var authors: Dictionary = {
#	author_name<String> = web_link_or_empty<String>
}
@export var license_name: String
@export var license_link: String
@export var original_source_link: String
