fs = require 'fs'
path = require 'path'

class File    
    constructor: (@filename) ->
        @dependencies = []
        @compiled = ''
        @sync = false
    
    # holds references to loaded files    
    @files: {}
    
    # framework search path (by default, a frameworks 
    # directory inside the current directory)
    @frameworkPath: "frameworks/"

    # keep track of what files have already been imported
    imported = {}
    
    # the regular expression used to find import statements
    importRe = /(?:#|\/\/)import (".+"|<.+>);?$/gm
    
    # loads and parses files or returns them from the cache
    @load: (filename, isImport) ->
        imported = {} unless isImport
        
        # if the file has already been loaded, 
        # just return it from the cache
        if @files[filename]
            return @files[filename]
        
        file = new File(filename)
        @files[filename] = file
        return file
        
    @loadSync: (filename) ->
        file = @load filename
        file.sync = true
        return file
    
    @extensions:
        '.coffee': (code) -> 
            # convert CoffeeScript import comments into embedded 
            # JavaScript comments to be parsed after it is compiled
            code = code.replace(importRe, '`//import $1`')
            require('coffee-script').compile(code, bare: yes)
            
        '.js': (code) -> code
        
    resolve: (callback) ->
        fullname = path.resolve @filename
        
        # if the filename already has an extension, just use that
        if (ext = path.extname(fullname)) of File.extensions
            return @check fullname, ext, callback
        
        # try each of the supported extensions
        exts = Object.keys File.extensions
        do proceed = =>
            if exts.length
                ext = exts.shift()
                @check fullname + ext, ext, callback, proceed
            else
                callback new Error '"' + @filename + '" could not be found.'
                
    check: (filepath, ext, callback, proceed) ->
        # make sure the file exists and isn't a directory
        @fs 'stat', filepath, (err, stat) =>
            if err or stat.isDirectory()
                return proceed() if proceed
                return callback new Error '"' + @filename + '" could not be found.'

            # resolve symlinks
            @fs 'realpath', filepath, (err, realpath) ->
                callback err, realpath, ext, stat
                
    fs: (method, args..., callback) ->
        if @sync
            try
                callback null, fs[method + 'Sync'] args...
            catch err
                callback err
        else
            fs[method] args..., callback
                
    # actually reads the file contents and compiles CoffeeScript to JS
    load: (callback) ->
        # resolve the path
        @resolve (err, path, @ext, stat) =>
            return callback err, this if err
            
            # if the file and path haven't changed, use the cache
            return callback null, this if +stat.mtime is @mtime and path is @path
            @path = path
         
            # actually read the file
            @fs 'readFile', @path, 'utf8', (err, code) =>
                return callback err if err
                
                # catch compile errors
                try
                    @compiled = File.extensions[@ext](code)
                catch err
                    return callback "#{err} in #{@path}", this
                
                @mtime = +stat.mtime
                @parse callback
                    
    # parses and loads file dependencies
    parse: (callback) ->
        @dependencies = []
        importRe.lastIndex = 0 # reset the regex position
        
        # parse all #import statements and load dependencies
        do proceed = =>
            if result = importRe.exec(@compiled)
                filename = result[1].slice(1, -1)
                
                if result[1][0] is '<'
                    filename = path.join(File.frameworkPath, filename)
                
                # relative dependencies should default to the 
                # same directory as the parent
                if filename[0] isnt '/'
                    filename = path.join(path.dirname(@path), filename)
                
                file = File.load(filename, true)
                file.load (err, file) =>
                    return callback err, this if err
                    
                    # keep track of the offset and length of the import statement
                    @dependencies.push
                        offset: result.index
                        length: result[0].length
                        file: file
                    
                    proceed()
            else
                callback null, this
    
    # recursively compiles all dependencies and itself into
    # the final composite output            
    compile: (callback) ->
        # reload the file if necessary
        @load (err) =>
            return callback err if err
            
            # make sure we don't import things more than once
            # to avoid recursive imports
            imported[@path] = true
            
            # compile all dependencies
            code = []
            deps = [@dependencies...]
            last = 0

            do proceed = =>
                if deps.length
                    dep = deps.shift()
                    
                    # if the file has already been imported, just ignore it
                    if imported[dep.file.path]
                        last = dep.offset + dep.length + 1
                        return proceed()
                    
                    # include the code from this file between the 
                    # previous import statement and this one
                    if dep.offset > last
                        code.push @compiled.slice(last, dep.offset)
                    
                    # move the last position forward
                    last = dep.offset + dep.length + 1
                                        
                    # compile the dependency
                    dep.file.compile (err, depCode) ->
                        return callback err if err
                        code.push depCode
                        proceed()
                        
                else
                    # return the output
                    code.push @compiled.slice(last)
                    callback null, code.join '\n'

# exported module
exports.extensions = File.extensions
Object.defineProperty exports, 'frameworkPath',
    set: (v) -> File.frameworkPath = v                    

exports.build = (mainFile, fn) ->
    File.load(mainFile).compile(fn)
    
exports.require = (mainFile) ->
    # even though this looks async, it's actually synchronous
    file = File.loadSync(mainFile)
    ret = null
    file.compile (err, code) ->
        throw err if err
        
        Module = require 'module'
        
        mod = new Module(mainFile, module)
        mod.filename = file.path
        mod.paths = Module._nodeModulePaths(path.dirname(file.path))
        
        ret = mod._compile(code, file.path)
        
    return ret