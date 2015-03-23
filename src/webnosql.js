// Generated by CoffeeScript 1.9.1
(function() {
  var ObjectID, WebNoSQL, WebNoSQL_DB, WebNoSQL_Query, defaultDBopts, log;

  ObjectID = (function() {
    function ObjectID(val1) {
      var i, j;
      this.val = val1 != null ? val1 : void 0;
      if (this.val === void 0) {
        this.val = Math.floor(new Date().getTime() / 1000).toString(16);
        for (i = j = 0; j <= 2; i = ++j) {
          this.val += (Math.random() * 16 | 0).toString(16);
        }
      }
    }

    ObjectID.prototype.getTimestamp = function() {
      return parseInt(this.val.substr(0, 8), 16);
    };

    ObjectID.prototype.valueOf = function() {
      return this.val.toString();
    };

    return ObjectID;

  })();

  log = {
    error: function(text) {
      return console.error(text);
    },
    warn: function(text) {
      return console.warn(text);
    },
    log: function(text) {
      return console.log(text);
    }
  };

  defaultDBopts = {
    version: '1.0',
    desc: '',
    size: 1024 * 1024
  };

  WebNoSQL_Query = (function() {
    function WebNoSQL_Query($wnsdb, $name) {
      this.$wnsdb = $wnsdb;
      this.$name = $name;
      this.opts = [];
    }

    WebNoSQL_Query.prototype._add_opts = function(opts) {
      var key, val;
      if (opts.type === void 0) {
        if (this.opts.length === 0 || this.opts[this.opts.length - 1].type !== "find") {
          log.warn("Wrong options used");
        } else {
          for (key in opts) {
            val = opts[key];
            this.opts[this.opts.length - 1][key] = val;
          }
        }
      } else {
        this.opts.push(opts);
      }
      return this;
    };

    WebNoSQL_Query.prototype.insert = function(data) {
      return this._add_opts({
        data: data,
        type: "insert"
      });
    };

    WebNoSQL_Query.prototype.update = function(filter, data, opts) {
      if (opts == null) {
        opts = void 0;
      }
      return this._add_opts({
        filter: filter,
        data: data,
        opts: opts
      });
    };

    WebNoSQL_Query.prototype.find = function(filter) {
      if (filter == null) {
        filter = void 0;
      }
      return this._add_opts({
        type: "find",
        filter: filter
      });
    };

    WebNoSQL_Query.prototype.limit = function(num1, num2) {
      if (num2 == null) {
        num2 = void 0;
      }
      return this._add_opts({
        limit: [num1, num2]
      });
    };

    WebNoSQL_Query.prototype.sort = function() {
      return this._add_opts({
        sort: sort
      });
    };

    WebNoSQL_Query.prototype["delete"] = function(filter) {
      return this._add_opts({
        type: "delete",
        filter: filter
      });
    };

    WebNoSQL_Query.prototype.drop = function() {
      return this._add_opts();
    };

    WebNoSQL_Query.prototype._do_options = function(tx, cb) {
      return console.log(this.opts);
    };

    WebNoSQL_Query.prototype.then = function(cb) {
      var self;
      if (cb == null) {
        cb = void 0;
      }
      self = this;
      return this.$wnsdb.$db.transaction(function(tx) {
        return tx.executeSql("SELECT * FROM sqlite_master WHERE type='table' and tbl_name=?", [self.$name], function(tx, results) {
          if (results && results.rows.length) {
            console.log("table ex");
            return self._do_options(tx, cb);
          } else {
            console.log("no table");
            return tx.executeSql("CREATE TABLE IF NOT EXISTS " + self.$name + "(_id TEXT PRIMARY KEY, data TEXT)", [], function(tx, results) {
              return self._do_options(tx, cb);
            }, function(error) {
              return log.error("Unable to create collection " + self.$name);
            });
          }
        }, function(error) {
          return log.error("Something wrong with table " + self.$name);
        });
      });
    };

    WebNoSQL_Query.prototype.run = function() {
      return this.then();
    };

    return WebNoSQL_Query;

  })();

  WebNoSQL_DB = (function() {
    function WebNoSQL_DB($name, opts) {
      var e;
      this.$name = $name;
      if (opts == null) {
        opts = {};
      }
      this.$db = void 0;
      this.$tbls = [];
      this.$opts = {
        version: opts.version || defaultDBopts.version,
        desc: opts.desc || defaultDBopts.desc,
        size: opts.size || defaultDBopts.size
      };
      try {
        this.$db = openDatabase(this.$name, this.$opts.version, this.$opts.desc, this.$opts.size);
      } catch (_error) {
        e = _error;
        log.error('Unable to open db "' + this.$name + '"');
      }
    }

    WebNoSQL_DB.prototype.$sql_call = function(sql, ret, cb) {
      if (ret == null) {
        ret = true;
      }
      if (cb == null) {
        cb = void 0;
      }
      if (this.$db !== void 0) {
        return this.$db.transaction(function(tx) {
          return tx.executeSql(sql, [], function(tx, results) {
            var i, items, j, ref;
            items = void 0;
            if (ret) {
              items = [];
              if (results && results.rows.length) {
                for (i = j = 0, ref = results.rows.length - 1; 0 <= ref ? j <= ref : j >= ref; i = 0 <= ref ? ++j : --j) {
                  items.push(results.rows.item(i));
                }
              }
            }
            if (cb !== void 0) {
              return cb(false, items);
            }
          }, function(error) {
            if (cb !== void 0) {
              return cb(true);
            }
          });
        });
      }
    };

    WebNoSQL_DB.prototype.tables = function(cb) {
      return this.$sql_call("SELECT * FROM sqlite_master WHERE type='table'", function(error, items) {
        var item, j, len, res_items;
        if (error) {
          return cb(error);
        } else {
          res_items = [];
          for (j = 0, len = items.length; j < len; j++) {
            item = items[j];
            res_items.push(item.tbl_name);
          }
          return cb(false, res_items);
        }
      });
    };

    WebNoSQL_DB.prototype.collection = function(name) {
      return new WebNoSQL_Query(this, name);
    };

    return WebNoSQL_DB;

  })();

  WebNoSQL = (function() {
    function WebNoSQL() {
      this.open_dbs = {};
    }

    WebNoSQL.prototype.isDriverAvailable = function() {
      if (window.openDatabase) {
        return true;
      } else {
        return false;
      }
    };

    WebNoSQL.prototype.use = function(db_name, opts) {
      if (opts == null) {
        opts = void 0;
      }
      if (this.isDriverAvailable()) {
        if (this.open_dbs[db_name] === void 0) {
          this.open_dbs[db_name] = new WebNoSQL_DB(db_name, opts);
        }
        return this.open_dbs[db_name];
      } else {
        return log.error("No SQL support in your browser");
      }
    };

    return WebNoSQL;

  })();

  window.webnosql = new WebNoSQL();

}).call(this);

//# sourceMappingURL=webnosql.js.map
