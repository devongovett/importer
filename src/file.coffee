fs = require 'fs'
path = require 'path'
utils = require './utils'
{IMPORT_RE, extensions:EXTENSIONS} = require './importer'
SourceMap = require './sourcemap'

# Represents an individual file in a package
class File
    constructor: (@package, @filename) ->
        @path = null
        @ext = null
        @mtime = null
        @dependencies = []
        @source = ''
        @compiled = ''
        @sourceMap = null
        @cache = ''
            
    # Resolves the full path to the file and checks if it 
    # has changed since the last time the file was loaded.
    resolve: (callback) ->
        fullname = path.resolve @filename
        
        # try each of the supported extensions
        changed = false
        check = (ext, fn) =>
            utils.stat @package.sync, fullname + ext, (err, stat) =>
                # make sure the file exists and isn't a directory
                return fn false if err or stat.isDirectory()
                    
                # follow any symlinks
                utils.realpath @package.sync, fullname + ext, (err, realpath) =>
                    return fn false if err
                    
                    if +stat.mtime isnt @mtime or realpath isnt @path
                        @mtime = +stat.mtime
                        @path = realpath
                        changed = true
                        
                    @ext = ext
                    fn true
                    
        done = (found) =>
            if not found
                @path = @mtime = @ext = null
                return callback new Error '"' + @filename + '" could not be found.'
                
            callback null, changed
                
        # if the filename already has an extension, just use that
        ext = path.extname fullname
        if ext of EXTENSIONS
            fullname = fullname.slice(0, -ext.length)
            return check ext, done
        
        # otherwise, check all of the extensions
        utils.some @package.sync, Object.keys(EXTENSIONS), check, done
                
    # Parses file dependencies using the regex defined at the top of the file
    parse: ->
        @dependencies.length = 0
        IMPORT_RE.lastIndex = 0 # reset the regex position
        
        while result = IMPORT_RE.exec(@compiled)
            filename = result[1].slice(1, -1)
            
            # if this is a framework dependency, make it relative to the frameworkPath
            if result[1][0] is '<'
                filename = path.join(path.resolve(@package.frameworkPath), filename)
                
            # relative dependencies should default to the 
            # same directory as the parent
            if filename[0] isnt '/'
                filename = path.join(path.dirname(@path), filename)
            
            # keep track of the offset and length of the import statement
            @dependencies.push
                offset: result.index
                length: result[0].length
                file: @package.load(filename)
                
        return
        
    # Resolves the path, reads the file, 
    # compiles it, and parses the dependencies
    load: (callback) =>
        # resolve the path
        @resolve (err, changed) =>
            if err or not changed
                return callback err, changed
            
            # actually read the file
            utils.readFile @package.sync, @path, 'utf8', (err, @source) =>
                return callback err if err
                
                # catch compile errors
                try
                    compiled = EXTENSIONS[@ext](@source, !!@package.sourceMap)
                catch err
                    @mtime = null
                    throw err
                    return callback new Error "#{err} in #{@path}"
                    
                if typeof compiled is 'string'
                    @compiled = compiled
                    @sourceMap = null
                else
                    @compiled = compiled.code
                    @sourceMap = compiled.map
                
                @parse()
                callback null, changed
    
    # Recursively compiles all dependencies and itself into
    # the final composite output
    compile: (callback) ->
        # reload the file if necessary        
        @load (err, changed) =>
            return callback err if err
            
            # make sure we don't import things more than once
            # to avoid recursive imports
            if @package.imported[@path]
                return callback null, null
            
            @package.imported[@path] = true
            
            # compile and merge all dependencies
            compileDependency = (dep, fn) ->
                dep.file.compile fn
                
            utils.mapSeries @package.sync, @dependencies, compileDependency, (err, deps) =>
                return callback err if err
                
                # if this file and no dependencies changed, we don't need to do anything
                changed or= deps.some (dep) -> dep
                if @cache and not changed
                    return callback null, false
                    
                # if something changed, we need to rebuild
                @cache = new SourceMap
                    source:        @source
                    compiled:      @compiled
                    makeSourceMap: @package.sourceMap
                    inSourceMap:   @sourceMap
                    filename:      path.relative(process.cwd(), @path)
                
                for dep, i in @dependencies
                    # include the code from this file between the 
                    # previous import statement and this one
                    @cache.addSegment dep.offset
                        
                    # skip the import statement itself in the output
                    @cache.compiledOffset += dep.length + 1
                    
                    # add the dependency
                    if deps[i]?
                        @cache.addSource dep.file.cache
                        
                @cache.addSegment @compiled.length
                callback null, true
                
module.exports = File