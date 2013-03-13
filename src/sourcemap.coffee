{SourceMapGenerator, SourceMapConsumer} = require 'source-map'

# This class generates the output code and source map
# It takes a string containing an entire file in, and adds
# segments of that file (between the import statements) and
# the contents of other files to create the composite output.
class SourceMap
    constructor: ({ @source, @compiled, @makeSourceMap, inSourceMap, @filename }) ->
        @sources = {}
        @sources[@filename] = @source
        
        @code = []
        @compiledOffset = 0
        
        if @makeSourceMap
            if inSourceMap
                @originalMap = new SourceMapConsumer inSourceMap
                
            @map = new SourceMapGenerator
                file: @filename
            
            @mappingOffset = 0
            @inputLine = 1
            @line = 1
    
    # Adds a segment of the @compiled to the output @code 
    # between the last @compiledOffset and the new offset
    addSegment: (offset) ->
        return if offset is @compiledOffset
        
        # Add the code itself
        str = @compiled.slice @compiledOffset, offset
        @compiledOffset = offset
        @code.push str
        
        return unless @makeSourceMap
        lines = str.split '\n'
        
        # If we were given an input source map, add the mappings
        # between the last offset and the new one to the output source map
        if @originalMap
            mappings = @originalMap._generatedMappings
            mapping = mappings[@mappingOffset]
            start = mapping
            
            endLine = start.generatedLine + lines.length - 1
            endColumn = lines[lines.length - 1].length
            
            while mapping?.generatedLine < endLine or mapping?.generatedColumn < endColumn
                @map.addMapping
                    source: @filename
                    generated:
                        line: @line + mapping.generatedLine - start.generatedLine
                        column: mapping.generatedColumn
                    original:
                        line: mapping.originalLine
                        column: mapping.originalColumn
                
                mapping = mappings[++@mappingOffset]
        
        # Otherwise, just add a direct line to line mapping
        else            
            for line, i in lines when line.length > 0
                @map.addMapping
                    source: @filename
                    generated:
                        line: @line + i
                        column: 0
                    original:
                        line: @inputLine + i
                        column: 0
                        
        @line += lines.length - 1
        @inputLine += lines.length - 1
        
    # Appends another SourceMap to this one
    addSource: (sourceMap) ->
        # Add the code itself
        @code.push sourceMap.code...
        for file, source of sourceMap.sources
            @sources[file] = source
        
        return unless @makeSourceMap
        
        # Add the source mappings
        for mapping, i in sourceMap.map._mappings
            @map.addMapping
                source: mapping.source
                generated: 
                    line: @line + mapping.generated.line - 1
                    column: mapping.generated.column
                original:
                    line: mapping.original.line
                    column: mapping.original.column
                    
        @line += sourceMap.line - 1
        
    # Returns the code as a string
    toString: ->
        return @code.join ''
        
    # Returns the generated JSON source map
    # and inlines the original source files
    toJSONSourceMap: ->
        return null unless @makeSourceMap
        
        json = @map.toJSON()
        json.sourcesContent = []
        for source in json.sources
            json.sourcesContent.push @sources[source]
            
        return json
        
module.exports = SourceMap