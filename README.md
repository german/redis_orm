RedisOrm supposed to be *almost* drop-in replacement of ActiveRecord. It's based on the [Redis](http://redis.io) key-value storage and is work in progress.

Here's the standard model definition:

```ruby
class User < RedisOrm::Base
  property :first_name, String
  property :last_name, String
  property :created_at, Time
  property :modified_at, Time
  
  index :last_name
  index [:first_name, :last_name]
  
  has_many :photos
  has_one :profile
  
  after_create :create_mailboxes
  
  def create_mailboxes
    # ...
  end
end
```

## Defining a model and specifing properties

To specify properties for your model you should use the following syntax:

```ruby
class User < RedisOrm::Base
  property :first_name, String
  property :last_name, String
  property :created_at, Time
  property :modified_at, Time
end
```

Following property types are supported:

*  **Integer**

*  **String**

*  **Float**

*  **RedisOrm::Boolean**

*  **Time**

The value of the 
Property definition supports following options:

*  **:default**

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

You could add index to any attribute of the model (it also could be compound):

```ruby
class User < RedisOrm::Base
  property :first_name, String
  property :last_name, String

  index :first_name
  index [:first_name, :last_name]
end
```

With index defined for the property (or number of properties) the id of the saved object is stored in the special sorted set, so it could be found later. For example with defined User model for the above code:

```ruby
user = User.new :first_name => "Robert", :last_name => "Pirsig"
user.save

# 2 redis keys are created "user:first_name:Robert" and "user:first_name:Robert:last_name:Pirsig" so we could search things like this:

User.find_by_first_name("Robert")                             # => user
User.find_all_by_first_name("Robert")                         # => [user]
User.find_by_first_name_and_last_name("Robert", "Pirsig")     # => user
User.find_all_by_first_name_and_last_name("Chris", "Pirsig")  # => []
```

Index definition supports following options:

*  **:unique** Boolean default: false

## Associations

RedisOrm provides 3 association types:

* has_one

* has_many

* belongs_to

HABTM association could be emulated with 2 has_many declarations in related models.

## Validation

RedisOrm includes ActiveModel::Validations. So all well-known functions are already in. An example from test/validations_test.rb:

```ruby
class Photo < RedisOrm::Base
  property :image, String
  
  validates_presence_of :image
  validates_length_of :image, :in => 7..32
  validates_format_of :image, :with => /\w*\.(gif|jpe?g|png)/
end
```

## Callbacks

RedisOrm provides 6 standard callbacks:

```ruby
after_save :callback
before_save :callback
after_create :callback
before_create :callback
after_destroy :callback
before_destroy :callback
```

They are implemented differently than in ActiveModel though work as expected:

```ruby
class Comment < RedisOrm::Base
  property :text, String
  
  belongs_to :user

  before_save :trim_whitespaces

  def trim_whitespaces
    self.text = self.text.strip
  end
end
```

## Saving records

When saving object to Redis new Hash is created with keys/values equal to the properties/values of the saving object. The object then 

## Tests

Though I a fan of the Test::Unit all tests are based on RSpec. And the only reason I did it is before(:all) and after(:all) hooks. So I could spawn/kill redis-server's process:

```ruby
describe "check callbacks" do
  before(:all) do
    path_to_conf = File.dirname(File.expand_path(__FILE__)) + "/redis.conf"
    $redis_pid = spawn 'redis-server ' + path_to_conf, :out => "/dev/null"
    sleep(0.3) # must be some delay otherwise "Connection refused - Unable to connect to Redis"
    path_to_socket = File.dirname(File.expand_path(__FILE__)) + "/../redis.sock"
    $redis = Redis.new(:host => 'localhost', :path => path_to_socket)
  end
  
  before(:each) do
    $redis.flushall if $redis
  end

  after(:each) do
   $redis.flushall if $redis
  end

  after(:all) do
    Process.kill 9, $redis_pid.to_i if $redis_pid
  end
  
  # it "should ..." do
  #   ...
  # end
end
```

Copyright © 2011 Dmitrii Samoilov, released under the MIT license
