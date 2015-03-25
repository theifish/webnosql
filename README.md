# webnosql
You use JavaScript objects and JSON, you like it, you want to use it everywhere. Whe do you need to use uncomfortable SQL and strict tables structure in WebSQL?

NoSQL is more native for JavaScript, though WebNoSQL is an intelligent layer over typical WebSQL in MongoDB style.

# Documentation

## How to use

Get sources from GitHub and include it in your project. You'll get a new global object **webnosql**.

```
var db;

// Open database
db = webnosql.use("my_db");

// Insert some data into collection
rand_arr = ["one", "two", "three"];

for (var i = 0; i < 10; i++) {
    db.collection("my_coll").insert({a: Math.floor(Math.random() * 100), b: rand_arr[Math.floor(Math.random() * 2)]}).exec();
}

// Read data from the collection
db.collection("my_coll").find({a: {$gt: 50}, b: "three"}).then(function (error, items) {
    if (error) {
        console.error("Error was occurred");
    } else {
        // do something with items
    }
});
```

## Objects

### ObjectID

Unique id. Generates and use for unique _id rows column in collection.

Formula of id: current unix timestamp (4 bytes) + 3 random bytes

Methods:

**getTimestamp**

Returns timestamp from the value

**toString**

Returns value as string

### WebNoSQL

Main class. **webnosql** is a singleton instance of it.

Methods:

**isDriverAvailable**

Check if WebSQL available.

Returns true or false

**use (name, opts)**

Get a database.

Parameters:

- name - string, name of the database you want to use. required
- opts - object, options, optional. Inside opts: version - db version (default: 1.0), desc: db description (default: ''), size: db size (default: 1024*1024)

Returns instance of WebNoSQL_DB

**collections**

Get all collections exist.

Returns array with collections names

### WebNoSQL_DB

DB class.

Methods:

**collections**

Get all collections exist in the db.

Returns array with collections names.

**collection (name)**

Get collection.

Parameters:

- name - string, required. Name of the collection.

Returns instance of WebNoSQL_Collection

### WebNoSQL_Collection

Collection class.

Methods:

**insert (data)**

Insert some data into the collection.

Parameters:

- data - object, required. Data to insert.

Returns this.

**update (filter, data, opts)**

Update items in the collection.

Parameters:

- filter - object, required. Condition for the data update, see section **Filter**
- data - string, required. Data to update.
- opts - object, optional. Update options.

Returns this.

**delete (filter)**

Delete items in the collection.

Parameters:

- filter - object, optional. Condition, see section **Filter**

Return this.

**drop**

Drop collection. Not implemented yet.

**count (filter)**

Count items with filter.

Parameters:

- filter - object, required. Condition, see section **Filter**

Return this.

**find (filter)**

Find items in the collection.

Parameters:

- filter - object, optional. Condition, see section **Filter**

Return this.

**limit (num1, num2)**

Limit items. Use only with find.

Parameters:

- num1 - int, required. Limit to num1 items if num2 is defined, else point start of limit begin.
- num2 - int, optional. Limit to num2 items from num1 start point.

Return this.

**sort (sort)**

Sort items. Use onky with find.

Parameters:

- sort - object, required.

Return this.

**then (callback)**

Start the transaction.

Parameters:

callback - function, optional. Function parameters: error - error flag, items - items list.

**run**

Run the transaction. (Same as then without callback).

**exec**

Alias for run.
