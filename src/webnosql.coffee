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
    @_add_opts({type: "update", filter: filter, data: data, opts: opts})

  find: (filter = undefined) ->
    @_add_opts({type: "find", filter: filter})

  limit: (num1, num2 = undefined ) ->
    @_add_opts({limit: [num1, num2]})

  sort: (sort) ->
    @_add_opts({sort: sort})

  delete: (filter = undefined) ->
    @_add_opts({type: "delete", filter: filter})

  count: (filter = undefined) ->
    @_add_opts({type: "count", filter: filter})

  drop: ->
    @_add_opts({type: "drop"})

  _construct_where: (name, obj) ->
    if typeof obj == "int" || typeof obj == "float" || typeof obj == "boolean"
      return name + "=" + obj.toString()
    else if typeof obj == "object"
      res = ""
      for key,o in obj
        if key == "$in" && typeof o == "array"
          res+= " and " if res != ""
          res += name + " in " + JSON.stringify(o)
        else if key == "&lt"
          res+= " and " if res != ""
          res += name + " < " + JSON.stringify(o)
        else if key == "&gt"
          res+= " and " if res != ""
          res += name + " > " + JSON.stringify(o)
    else
      obj = obj.toString() if obj != "string"
      return name + "='" + obj.replace("'", "\'") + "'"

  _item_is_in_scope: (item, filter, filter_columns, operation = "and") ->
    result = false
    for own key, fval of filter
      if key.substr(0,1) == "$"
        if key == "$or"
          tmp = @_item_is_in_scope(item, fval, filter_columns, "or")
          if operation == "and" && !tmp
            return false
          else
            result = result || tmp
        if key == "$and"
          tmp = @_item_is_in_scope(item, fval, filter_columns, "and")
          if operation == "and" && !tmp
            return false
          else
            result = result || tmp
        else if key == "$not"
          tmp = !@_item_is_in_scope(item, fval, filter_columns, "or")
          if operation == "and" && !tmp
            return false
          else
            result = result || tmp
      else
        if key in filter_columns
          if typeof fval == "object"
            loc_result = true
            for op, opv of fval
              if op == "$lt"
                loc_result = loc_result && item[key] < opv
              else if op == "$gt"
                loc_result = loc_result && item[key] > opv
              else if op == "$in"
                loc_result = loc_result && item[key] in opv
            if operation == "and" && !loc_result
              return false
            else
              result = result || loc_result
          else
            if operation == "and" && item[key] != fval
              return false
            else
              result = result || item[key] == fval
    return result

  _filter_columns: (filter) ->
    result = []
    for own key, item of filter
      if key.substr(0,1) == "$"
        tmp = @_filter_columns(item)
        for e in tmp
          result.push(e) if e not in result
      else
        result.push(key) if key not in result
    result

  _get_items_from_rows: (rows, filter = undefined, limit = undefined, sort = undefined) ->
    items = []
    filter_columns = []
    filter_columns = @_filter_columns(filter) if filter != undefined
    if rows.length > 0
      for i in [0..rows.length - 1]
        tmp = rows.item(i)
        if tmp.data
          #try
            item = JSON.parse(tmp.data)
            item._id = tmp._id
            if filter == undefined || @._item_is_in_scope(item, filter, filter_columns)
              items.push(item)
          #catch e
          #  log.warn "Broken record #" + tmp._id
      if sort != undefined
        sort_func = (a, b) ->
          sort_res = 0
          for key, val of sort
            if a[key] == undefined && b[key] != undefined
              if val == 1 || val == -1
                return val
            else if a[key] != undefined && b[key] == undefined
              if val == 1 || val == -1
                return -val
            else if a[key] != undefined && b[key] != undefined
              if val == 1 || val == -1
                if a[key] > b[key]
                  return val
                else if a[key] < b[key]
                  return -val
          return sort_res
        items.sort(sort_func)
      if limit != undefined
        if typeof limit == "number"
          items = items.splice(0, limit)
        else
          if limit[1] == undefined
            items = items.splice(0, limit[0])
          else
            items = items.splice(limit[0], limit[1])
      return items

  _select_rows: (tx, filter, limit, sort, cb) ->
    self = @
    sql = "SELECT * from " + @$name
    if filter && filter["_id"]
      sql+= " where " + @_construct_where("_id", filter["_id"])
    tx.executeSql(
      sql,
      [],
      (tx, results) ->
        cb(false, self._get_items_from_rows(results.rows, filter, limit, sort)) if cb != undefined
      (error) ->
        cb(true) if cb != undefined
    )

  _do_options: (tx, cb) ->
    self = @
    for key,o of @opts
      ((o, is_last) ->
        if o.type == "find"
          self._select_rows(
            tx,
            o.filter,
            o.limit,
            o.sort,
            (error, items) ->
              cb(error, items) if cb != undefined && is_last
          )
        else if o.type == "delete"
          if o.filter != undefined
            self._select_rows(
              tx,
              o.filter,
              undefined,
              undefined,
              (error, items) ->
                if !error && items.length == 0
                  cb(false) if cb != undefined && is_last
                else if !error
                  ids = ""
                  for key,val of items
                    ids+= "," if ids != ""
                    ids+= "'" + val._id + "'"
                  sql = "DELETE FROM " + self.$name + " WHERE _id in (" + ids + ")"
                  tx.executeSql(
                    sql,
                    [],
                    (tx, result) ->
                      cb(false) if cb != undefined && is_last
                    (error) ->
                      cb(true) if cb != undefined && is_last
                  )
                else
                  cb(true)
            )
          else
            sql = "DELETE FROM " + self.$name
            tx.executeSql(
              sql,
              [],
              (tx, result) ->
                cb(false) if cb != undefined && is_last
              (error) ->
                cb(true) if cb != undefined && is_last
            )
        else if o.type == "insert"
          id = new ObjectID()
          data = JSON.stringify(o.data || {})
          sql = "INSERT INTO " + self.$name + "(_id, data) VALUES('" + id + "', '" + data + "')"
          tx.executeSql(
            sql,
            [],
            (tx, result) ->
              cb(false, id) if cb != undefined && is_last
            (error) ->
              cb(true) if cb != undefined && is_last
          )
        else if o.type == "update"
          if o.filter != undefined
            self._select_rows(
              tx,
              o.filter,
              undefined,
              undefined,
              (error, items) ->
                if !error && items && items.length
                  for key,item of items
                    ((item, is_last) ->
                      _id = item._id
                      if o.data["$set"]
                        data = item
                        for key,val of o.data["$set"]
                          data[key] = val
                        delete data._id
                      else
                        data = o.data
                      sql = "UPDATE " + self.$name + " SET data='" + JSON.stringify(data) + "' WHERE _id='" + _id + "'"
                      tx.executeSql(
                        sql,
                        [],
                        (tx, result) ->
                          cb(false) if cb != undefined && is_last
                        (error) ->
                          cb(true) if cb != undefined && is_last
                      )
                    )(item, is_last && (parseInt(key,10) == items.length - 1))
                else if !error
                  cb(false) if cb != undefined && is_last
                else
                  cb(true) if cb != undefined && is_last
            )
        else if o.type == "count"
          if o.filter != undefined
            self._select_rows(
              tx,
              o.filter,
              undefined,
              undefined,
              (error, items) ->
                if !error && items && items.length
                  cb(false, items.length) if cb != undefined && is_last
                else if !error
                  cb(false, 0) if cb != undefined && is_last
                else
                  cb(true) if cb != undefined && is_last
            )
          else
            sql = "SELECT COUNT(_id) as cnt FROM " + self.$name
            tx.executeSql(
              sql,
              [],
              (tx, result) ->
                if result.rows.length
                  cb(false, result.rows.item(0).cnt) if cb != undefined && is_last
                else
                  cb(false, 0) if cb != undefined && is_last
              (error) ->
                cb(true) if cb != undefined && is_last
            )
      )(o, parseInt(key,10) == @opts.length - 1)


  then: (cb = undefined) ->
    self = @
    @$wnsdb.$db.transaction (tx) ->
      tx.executeSql(
        "SELECT * FROM sqlite_master WHERE type='table' and tbl_name=?",
        [self.$name],
        (tx, results) ->
          if results && results.rows.length
            self._do_options(tx, cb)
          else
            tx.executeSql(
              "CREATE TABLE IF NOT EXISTS " + self.$name + "(_id TEXT PRIMARY KEY, data TEXT)",
              [],
              (tx, results) ->
                self._do_options(tx, cb)
              (error) ->
                log.error("Unable to create collection " + self.$name)
                cb(true) if cb != undefined
            )
        (error) ->
          log.error("Something wrong with table " + self.$name)
          cb(true) if cb != undefined
      )

  run: ->
    @then()

  exec: ->
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