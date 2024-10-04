MSEP.one code style conventions

# Filename convention

snake_case for directories and filenames (Godot docs standard) (M) (B)


# Filename <-> class_name relationship

We should maintain relationship between filenames and class names, if file is named some_interesting_thing.gd, the class_name should not be different then SomeInterestingThing. 
This also means maintaining relation of 'one file <-> one public class' where possible


# Function naming conventions

* snake_case function names
* Always strongly typed where possible
  * When not possible comment next to a function containing parameter/return types


# Signal naming convention

* signal listeners always should be created with following convention: "_on" + "object_name" + verb defined by signal name, Signal verb usually will be in past tense, since signals usually reports about events which already happen, but there are rare cases where signal shout not in the past tense


# Annotations

One line style for @onready and @export annotations:
@export val: int = 3  
@onready var node: Node = get_node("node")

New lines are acceptable for any other more verbose annotations, or when line is simply too long


# **Logic operators**

Python style: [and] [or] [not] ( [&] and [|] for bit-wise operations)


# Comments

* Regular comments should start with a space, but not code that you comment out. This helps differentiate text comments from disabled code.
* Instead of using double quotation marks we should use 'documentation comments' for classes and functions using double ## comment.
Example:
```
## Returns the ProjectWorkspaceEditorContext associated to the active workspace
## Any node inside this viewport can access to it with the following code
## [br][code]
## var workspace_context: ProjectWorkspaceEditorContext = get_viewport().get_workspace_context()
## [/code]
func get_workspace_context():
	return _workspace_context
```


# New lines between functions

Two new lines between functions


# Variable naming conventions

* private members prefixed with "_"
* any kind of setter/getter longer then 2 lines should declare it's own function and use it (let's keep declarative part of the file clean from logic)
* parameters which are expected to be heavily modified by function should be prefixed with 'out_'
* When declaring a Dictionary or Array, always include type information 
  * If needed create a comment presenting a structure ex:

    ```
    var atoms: Dictionary = {
    	# "id" : id of the atom as integer
    	# "name" : atom's symbol name as string
    	# "color" : Color(1,1,1,1)
    }
    ```
* Variable names should be explicit and verbose
  * ( `p` is bad name, `point` is much better)

# Node naming conventions

* PascalCase node names


# Scene encapsulation

* Nodes which are having it's own script usually should be a scenes, they should be able to encapsulate it's inner parts from the rest of the world
  * Prefer using node  'unique name in owner' for fetching member nodes (especially in UI scenes where hierarchy is pretty fluent)


# File structure convention

File structure should reflect logic structure of the program, each scene should have it's own directory which contain scene file, script file and sub directories for other scenes and so on:  
* Optional directories allowed where it makes sense (usually for assets)  
* To some degree it should be possible to reason about the logic structure from the file structure, if given subscene is inside "Editor" scene that usually will mean "Editor" scene is responsible for creating and holding such subscene

# Order of declaration

 1. @tool
 2. class_name
 3. extends
 4. docstring
 5. signals
 6. enums
 7. constants
 8. @export variables
 9. public variables
10. private variables
11. @onready variables
12. optional built-in virtual _init method
13. built-in virtual _ready method
14. remaining built-in virtual methods
15. public and private methods


# End of line semicolon

Although GDscript allows semicolons at the end of the line, those should not be used.
