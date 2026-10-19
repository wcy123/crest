add_subdirectory(Interpreter)  # must precede Bindings (CrestBindings links it)
add_subdirectory(Crest)        # must precede Bindings (CrestBindings links CrestCore objects)
add_subdirectory(Bindings)
add_subdirectory(Passes)
