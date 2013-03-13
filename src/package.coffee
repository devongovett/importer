File = require './file'
UglifyJS = require 'uglify-js'
Module = require 'module'
path = require 'path'

# Represents a package containing a main file
# and serveral dependencies. Several options are
# available for packages, documented in the constructor.
class Package
    constructor: (@main, options = {}) ->
        # Whether to minify the output JavaScript
        @minify = options.minify ? false
        
        # Whether compilation should be synchronous
        # asynchronous by default
        @sync = options.sync ? false
        
        # Framework search path
        @frameworkPath = options.frameworkPath ? "./frameworks"
        
        # Whether to generate a source map, and if so, its url or filename
        @sourceMap = options.sourceMap ? false
        
        # Holds references to loaded files
        @files = {}
        
        # Keep track of what files have already been imported
        @imported = {}
        
        # The cached output, used if no files change
        @cache = ''
        
        # Load the main file
        @mainFile = @load @main
        
    # Loads a filename, either by creating a new 
    # File object or loading one from the cache.
    load: (filename) ->
        # if the file has already been loaded, 
        # just return it from the cache
        if @files[filename]
            return @files[filename]
            
        file = new File this, filename
        @files[filename] = file
        return file
        
    # Builds the package by compiling the main file.
    # If async, pass a callback function accepting an error
    # object and the resulting code. If sync, errors will be
    # thrown and the code returned to you.
    build: (callback) ->
        @imported = {}
        
        if @sync
            fn = (err, changed) =>
                throw err if err
                @reminify() if changed
                
        else
            fn = (err, changed) =>
                return callback err if err
                @reminify() if changed                
                callback null, @cache
        
        @mainFile.compile fn
        return @cache if @sync
        
    # Handles caching and minifying using uglify-js
    reminify: (changed) ->
        code = @mainFile.cache.toString()
        map = @mainFile.cache.toJSONSourceMap()
            
        if @minify            
            ast = UglifyJS.parse code
            ast.figure_out_scope()
            
            sq = UglifyJS.Compressor(warnings: no)
            ast = ast.transform(sq)
            
            ast.figure_out_scope()
            ast.compute_char_frequency()
            ast.mangle_names()
            
            map and= UglifyJS.SourceMap
                file: map.file
                orig: map
            
            code = ast.print_to_string
                source_map: map
                
        if @sourceMap
            code += "\n\n//@ sourceMappingURL=#{@sourceMap}"
            map = JSON.stringify(map)
            
        @cache = {code, map}
    
    # This synchronously compiles and executes a package directly in Node    
    require: ->
        # synchronously compile the code
        sync = @sync
        @sync = true
        
        {code} = @build()
        
        @sync = sync
        
        # load it into a node module
        mod = new Module(@main, module)
        mod.filename = @mainFile.path
        mod.paths = Module._nodeModulePaths(path.dirname(mod.filename))
        
        # execute it, and return the module's exports object
        return mod._compile(code, mod.filename)
        
module.exports = Package