def can_build(env, platform):
    if platform in ["windows"] and not env["use_mingw"]: # We only support mingw
        return False
    return True


def configure(env):
    pass

def get_opts(platform):
    from SCons.Variables import BoolVariable
    from SCons.Variables import PathVariable
    import os
    # Forces rebuild when building inside of our container.
    default_value = bool(os.getenv("ON_CONTAINER"))
    options = [
        BoolVariable("rebuild_zmq_lib", "Forces rebuilding of libzmq", default_value),
    ]
    return options

def get_doc_classes():
    return [
	    "LightningMemoryMappedDatabase",
    ]


def get_doc_path():
    return "doc_classes"
