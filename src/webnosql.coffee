class ObjectID
  constructor: (@val = undefined) ->
    if @val == undefined
      @val = Math.floor(new Date().getTime() / 1000).toString(16)
      for i in [0..2]
        @val+= (Math.random()*16|0).toString(16)

  getTimestamp: ->
    return parseInt(@val.substr(0,8), 16)

  valueOf: ->
    return @val.toString()

log =
  error: (text) ->
    console.error text
  warn: (text) ->
    console.warn text
  log: (text) ->
    console.log text

defaultDBopts =
  version: '1.0'
  desc: ''
  size: 1024*1024

class WebNoSQL_Query
  constructor: (@$wnsdb, @$name) ->
    @opts = []

  _add_opts: (opts) ->
    if opts.type == undefined
      if @opts.length == 0 || @opts[@opts.length - 1].type != "find"
        log.warn("Wrong options used")
      else
        for key,val of opts
          @opts[@opts.length - 1][key] = val
    else
      @opts.push(opts)
    @

  insert: (data) ->
    @_add_opts({data: data, type: "insert"})

  update: (filter, data, opts = undefined) ->
    @_add_opts({filter: filter, data: data, opts: opts})

  find: (filter = undefined) ->
    @_add_opts({type: "find", filter: filter})

  limit: (num1, num2 = undefined ) ->
    @_add_opts({limit: [num1, num2]})

  sort: () ->
    @_add_opts({sort: sort})

  delete: (filter) ->
    @_add_opts({type: "delete", filter: filter})

  drop: ->
    @_add_opts()

  _do_options: (tx, cb) ->
    console.log @opts

  then: (cb = undefined) ->
    self = @
    @$wnsdb.$db.transaction (tx) ->
      tx.executeSql(
        "SELECT * FROM sqlite_master WHERE type='table' and tbl_name=?",
        [self.$name],
        (tx, results) ->
          if results && results.rows.length
            console.log "table ex"
            self._do_options(tx, cb)
          else
            console.log("no table")
            tx.executeSql(
              "CREATE TABLE IF NOT EXISTS " + self.$name + "(_id TEXT PRIMARY KEY, data TEXT)",
              [],
              (tx, results) ->
                self._do_options(tx, cb)
              (error) ->
                log.error("Unable to create collection " + self.$name)
            )
        (error) ->
          log.error("Something wrong with table " + self.$name)
      )

  run: ->
    @then()

class WebNoSQL_DB
  constructor: (@$name, opts = {}) ->
    @$db = undefined
    @$tbls = []
    @$opts =
      version: opts.version || defaultDBopts.version
      desc: opts.desc || defaultDBopts.desc
      size: opts.size || defaultDBopts.size
    try
      @$db = openDatabase(@$name, @$opts.version, @$opts.desc, @$opts.size)
    catch e
      log.error('Unable to open db "' + @$name + '"')

  $sql_call: (sql, ret = true, cb = undefined) ->
    if @$db != undefined
      @$db.transaction (tx) ->
        tx.executeSql(
          sql,
          [],
          (tx, results) ->
            items = undefined
            if ret
              items = []
              if results && results.rows.length
                for i in [0..results.rows.length-1]
                  items.push(results.rows.item(i))
            cb(false, items) if cb!=undefined
          (error) ->
            cb(true) if cb != undefined
        )


  tables: (cb) ->
    @$sql_call "SELECT * FROM sqlite_master WHERE type='table'", (error, items) ->
      if error
        cb(error)
      else
        res_items = []
        for item in items
          res_items.push(item.tbl_name)
        cb(false, res_items)

  collection: (name) ->
    new WebNoSQL_Query(@, name)

class WebNoSQL
  constructor: ->
    @open_dbs = {}

  isDriverAvailable: ->
    if window.openDatabase
      return true
    else
      return false

  use: (db_name, opts = undefined) ->
    if @isDriverAvailable()
      if @open_dbs[db_name] == undefined
        @open_dbs[db_name] = new WebNoSQL_DB(db_name, opts)
      return @open_dbs[db_name]
    else
      log.error("No SQL support in your browser")

window.webnosql = new WebNoSQL()