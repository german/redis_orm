RedisOrm supposed to be *almost* drop-in replacement of ActiveRecord. It's based on the ![Redis](http://redis.io) key-value storage.
It's work in progress.

## Specifing attributes

To specify attributes for the model you should use following syntax:

```ruby
class User < RedisOrm::Base
  property :name, String
end
```

Following property types are supported:
  *Integer*
  *String*
  *Float*
  *RedisOrm::Boolean*
  *Time*

Attribute definition supports following options:
  *default*
    The default value of the attribute when it's getting saved w/o any.

## Searching records by the value

Usually it's done via specifing an index and using dynamic finders. For example:

```ruby
class User < RedisOrm::Base
  property :name, String

  index :name
end

User.create :name => "germaninthetown"
User.find_by_name "germaninthetown" # => found 1 record
User.find_all_by_name "germaninthetown" # => array with 1 record
```

Dynamic finders work mostly the way they work in ActiveRecord. The only difference is if you didn't specified index or compaund index on the attributes you are searching on the exception will be raised.

## Options for find/all 

For example we associate 2 photos with the album

```ruby
@album.photos << @photo2
@album.photos << @photo1
```

To extract all or part of the associated records by far  you could use 3 options (#find is an alias for #all in has_many proxy):

```ruby
@album.photos.all(:limit => 0, :offset => 0).should == []
@album.photos.all(:limit => 1, :offset => 0).size.should == 1
@album.photos.all(:limit => 2, :offset => 0)
@album.photos.find(:order => "asc")

Photo.all(:order => "asc", :limit => 5)
Photo.all(:order => "desc", :limit => 10, :offset => 50)
```

## Indices

Indices are used in a different way then they are used in relational databases. 

You could add index to any attribute of the model. Index could be compaund:

```ruby
class User < RedisOrm::Base
  property :first_name, String
  property :last_name, String

  index [:first_name, :last_name]
end
```

Index definition supports following options:
  *unique* Boolean default: false

## Associations

## Validation

## Callbacks

## Saving records

When saving object to Redis new Hash is created with keys/values equal to the properties/values of the saving object. The object then 

## Tests
