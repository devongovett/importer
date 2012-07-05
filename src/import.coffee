fs = require('fs')
path = require('path')
async = require('async')

parseFile = (full_path, cb) ->
  file =
    path: full_path
    compiled_js: null
    mtime: null
    deps: []
  fs.stat full_path, (err, stat) ->
    if err
      cb err
      return
    file.mtime = +stat.mtime
    fs.readFile full_path, 'utf8', (err, source) ->
      if err
        cb err
        return
      parser = parsers[path.extname(full_path)]
      try
        file.compiled_js = parser.compile(source)
      catch err
        cb err
        return
      # get the list of dependencies
      re = parser.import_re
      re.lastIndex = 0
      funcs = []
      while result = re.exec(source)
        import_string = result[1].slice(1, -1)
        # relative dependencies should default to the
        # same directory as the parent
        if import_string[0] isnt '/'
          import_string = path.join(path.dirname(full_path), import_string)
          funcs.push async.apply(resolvePath, import_string)
      async.parallel funcs, (err, results) ->
        if err
          cb err
          return
        file.deps = results
        cb null, file


resolvePath = (import_string, doneResolvingPath) ->
  resolveWithExt = (ext, cb) ->
    fs.realpath path.resolve(import_string + ext), (err, real_path) ->
      if err
        cb null, null
        return
      fs.stat real_path, (err, stat) ->
        if err or stat.isDirectory()
          cb null, null
        else
          cb null, real_path
    
  # try each of the supported extensions
  async.map [""].concat(Object.keys(parsers)), resolveWithExt, (err, results) ->
    async.filter results, ((item, cb) -> cb(item?)), (results) ->
      if results.length > 1
        doneResolvingPath("ambiguous import: #{import_string}")
        return
      doneResolvingPath null, results[0]

cached_files = {}
root = null

resolveDependencyChain = ->
  deps = []
  seen = {}
  processNode = (node) ->
    for dep_path in node.deps
      dep = cached_files[dep_path]
      if seen[dep.path]?
        continue
      seen[dep.path] = true
      # add deps first, then itself
      processNode dep
    deps.push node
  processNode(root)
  return deps

collectDependencies = (import_string, doneCollectingDependencies) ->
  resolvePath import_string, (err, canonical_path) ->
    if err
      doneCollectingDependencies(err)
      return

    parseAndHandleErr = (cb) ->
      parseFile canonical_path, (err, file) ->
        if err
          doneCollectingDependencies(err)
          return

        root ?= file

        cached_files[file.path] = file
        cb(file)

    callNext = (file) ->
      async.map file.deps, collectDependencies, doneCollectingDependencies

    if (cached_file = cached_files[canonical_path])?
      fs.stat canonical_path, (err, stat) ->
        if cached_file.mtime is +stat.mtime
          callNext cached_file
        else
          parseAndHandleErr callNext
    else
      parseAndHandleErr callNext


compile = (main_file, cb) ->
  collectDependencies main_file, (err) ->
    if err
      cb(err)
      return
    dependency_chain = resolveDependencyChain(root)
    output = (dep.compiled_js for dep in dependency_chain).join("\n")
    cb(null, output)

compile.extensions = parsers =
  '.coffee':
    compile: (code) -> require('coffee-script').compile code, bare: yes
    import_re: /^#import (".+")$/gm

  '.js':
    compile: (code) -> code
    import_re: /^\/\/import (".+");?$/gm

  '.co':
    compile: (code) -> require('coco').compile code, bare: yes
    import_re: /^#import (".+")$/gm

  '.ls':
    compile: (code) -> require('LiveScript').compile code, bare: yes
    import_re: /^#import (".+")$/gm

module.exports = compile
