path       = require 'path'
cloudfiles = require 'cloudfiles'
findit     = require 'findit'
crypto     = require 'crypto'
fs         = require 'fs'
querystring= require 'querystring'
config     = require './conf/conf.js'

opts = require('optimist')
    .usage('Usage: $0 container path')
    .options
      n: alias: 'dry-run', describe: "Don't actually make any changes", boolean: true
      v: alias: 'verbose', describe: "Make output chattier", boolean: true
      x: alias: 'exclude-root', describe: "Don't include top-level directory in uploaded path", boolean: true
    .demand 2

[containerName, uploadPath] = opts.argv._

dryRun = opts.argv.n
verbose = opts.argv.v

uploadPath = path.resolve uploadPath


getRelative = (p, container) ->
  if typeof container == undefined or opts.argv.x
    prefix = ''
  else
    prefix = container + '/'
  p.replace new RegExp("^#{uploadPath}/"), prefix

throttle = (limit, fn) ->
  queue = []
  active = 0

  dequeue = (cb) -> (args...) ->
    #console.log "function finished"
    cb args...
    active--
    if active < limit && queue.length > 0
      #console.log "shifting deferred function from queue"
      [that, args] = queue.shift()
      fn.apply that, args

  (args...) ->
    cb = args[args.length-1]
    args[args.length-1] = dequeue(cb)

    if active < limit
      #console.log "immediately running function"
      active++
      fn.apply this, args
    else
      #console.log "deferring function"
      queue.push [this, args]

auth = config.auth

client = cloudfiles.createClient {auth}

client.throttledAddFile = throttle 2, client.addFile
client.throttledDestroyFile = throttle 2, client.destroyFile

client.setAuth ->
  client.createContainer containerName, (err, container) ->
    return console.log "ERROR", err if err

    files = {}

    fetchList containerName, false, files

fetchList = (containerName, marker, files, soFar) ->
  if typeof soFar == 'undefined'
    soFar = []
  client.getFiles containerName,marker, (err, serverFiles) ->
    return console.log "ERROR", err if err
    # Default max return for the rackspace API is 10000.
    if serverFiles.length == 10000
      marker = serverFiles[serverFiles.length - 1].name
      soFar = soFar.concat(serverFiles)
      fetchList containerName, marker, files, soFar
    else
      serverFiles = serverFiles.concat(soFar)
      for file in serverFiles
        files[file.name] = file

      console.log files

      finder = findit.find uploadPath
      finder.on 'file', (file, stat) ->
        return
        relative = getRelative file, containerName
        for part in relative.split('/')
          return if part[0] == '.'

        sFile = files[relative]
        localHash = crypto.createHash('md5').update(fs.readFileSync(file)).digest('hex')

        if !sFile or localHash != sFile.hash
          console.log "uploading", relative
          
          unless dryRun
            client.throttledAddFile containerName, remote: relative, local: file, (err, uploaded) ->
              return console.log "ERROR", err if err
              console.log "uploaded", relative
        else
          if verbose
            console.log "skipping", relative

        delete files[relative]

      finder.on 'end', ->
        for name of files
          do (name) ->
            console.log "deleting", name
            
            unless dryRun
              client.throttledDestroyFile containerName, name, (err, result) ->
                return console.log "ERROR", err if err
                console.log "deleted", name
