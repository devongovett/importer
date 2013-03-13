async = require 'async'
fs = require 'fs'

# wrap fs function Sync versions so that we can reuse the same code for
# async and sync versions using a boolean flag. The code will look async, 
# but will actually be synchronous depending on the flag. Hacky, but it 
# improves code reuse.
setupFs = (key) ->
    return unless fs[key + 'Sync']?
    
    exports[key] = (sync, args..., callback) ->
        if sync
            suffix = if sync then 'Sync' else ''
            
            try
                ret = fs[key + suffix](args...)
            catch err
                return callback err
        
            callback null, ret
        
        else
            fs[key](args..., callback)

for key of fs
    setupFs key

# Now do the same thing for the async module's functions. This overwrites
# async.nextTick temporarily to perform the callback synchronously if needed.
nextTick = async.nextTick
fakeNextTick = (fn) -> fn()

setupAsync = (key, errs, arrKey = key) ->
    exports[key] = (sync, args...) ->
        if sync
            async.nextTick = fakeNextTick
            
        async[key](args...)
        async.nextTick = nextTick
        
for key of async
    setupAsync key