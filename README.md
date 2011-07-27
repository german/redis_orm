RedisOrm supposed to be *almost* drop-in replacement of ActiveRecord 2.x. It's based on the [Redis](http://redis.io) - advanced key-value store and is work in progress.

Here's the standard model definition:

```ruby
class User < RedisOrm::Base
  property :first_name, String
  property :last_name, String
  
  timestamps
  
  # OR
  # property :created_at, Time
  # property :modified_at, Time
  
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

## Setting up a connection to the redis server

If you are using Rails you should initialize redis and set up global $redis variable in *config/initializers/redis.rb* file:

```ruby
require 'redis'
$redis = Redis.new(:host => 'localhost', :port => 6379)
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

Supported property types:

*  **Integer**

*  **String**

*  **Float**

*  **RedisOrm::Boolean**
    there is no Boolean class in Ruby so it's a special class to store TrueClass or FalseClass objects

*  **Time**

Following options are available in property declaration:

*  **:default**

    The default value of the attribute when it's getting saved w/o any.

## Searching records by the value

Usually it's done via declaring an index and using *:conditions* hash or dynamic finders. For example:

```ruby
class User < RedisOrm::Base
  property :name, String

  index :name
end

User.create :name => "germaninthetown"

# via dynamic finders:
User.find_by_name "germaninthetown" # => found 1 record
User.find_all_by_name "germaninthetown" # => array with 1 record

# via *:conditions* hash:
User.find(:all, :conditions => {:name => "germaninthetown"}) # => array with 1 record
User.all(:conditions => {:name => "germaninthetown"}) # => array with 1 record
```

Dynamic finders work mostly the way they work in ActiveRecord. The only difference is if you didn't specified index or compound index on the attributes you are searching on the exception will be raised. So you should make an initial analysis of model and determine properties that should be searchable.

## Options for #find/#all

To extract all or part of the associated records you could use 4 options:

* :limit

* :offset

* :order

  Either :desc or :asc (default), since records are stored with *Time.now.to_f* scores, by default they could be fetched only in that (or reversed) order. To store them in different order you should *zadd* record's id to some other sorted list manually.
  
* :conditions

  Hash where keys must be equal to the existing property name (there must be index for this property too).

```ruby
# for example we associate 2 photos with the album
@album.photos << Photo.create(:image_type => "image/png", :image => "boobs.png")
@album.photos << Photo.create(:image_type => "image/jpeg", :image => "facepalm.jpg")

@album.photos.all(:limit => 0, :offset => 0) # => []
@album.photos.all(:limit => 1, :offset => 0).size # => 1
@album.photos.all(:limit => 2, :offset => 0) # [...]
@album.photos.all(:limit => 1, :offset => 1, :conditions => {:image_type => "image/png"})
@album.photos.find(:all, :order => "asc")

Photo.find(:first, :order => "desc")
Photo.all(:order => "asc", :limit => 5)
Photo.all(:order => "desc", :limit => 10, :offset => 50)
Photo.all(:order => "desc", :offset => 10, :conditions => {:image_type => "image/jpeg"})

Photo.find(:all, :conditions => {:image => "facepalm.jpg"}) # => [...]
Photo.find(:first, :conditions => {:image => "boobs.png"}) # => [...]
```

## Using UUID instead of numeric id

You could use universally unique identifiers (UUIDs) instead of a monotone increasing sequence of numbers as id/primary key for your models. 

Example of UUID: b57525b09a69012e8fbe001d61192f09. 

To enable UUIDs you should invoke *use_uuid_as_id* class method:

```ruby
class User < RedisOrm::Base
  use_uuid_as_id
  
  property :name, String

  property :created_at, Time
end
```

[UUID](https://rubygems.org/gems/uuid) gem is installed as a dependency. 

An excerpt from https://github.com/assaf/uuid :

UUID (universally unique identifier) are guaranteed to be unique across time and space. 

A UUID is 128 bit long, and consists of a 60-bit time value, a 16-bit sequence number and a 48-bit node identifier. 

Note: when using a forking server (Unicorn, Resque, Pipemaster, etc) you don’t want your forked processes using the same sequence number. Make sure to increment the sequence number each time a worker forks.

For example, in config/unicorn.rb:

```ruby
after_fork do |server, worker|
  UUID.generator.next_sequence
end
```

## Indices

Indices are used in a different way then they are used in relational databases. In redis_orm they are used to find record by they value rather then to quick access them.

You could add index to any attribute of the model (index also could be compound):

```ruby
class User < RedisOrm::Base
  property :first_name, String
  property :last_name, String

  index :first_name
  index [:first_name, :last_name]
end
```

With index defined for the property (or properties) the id of the saved object is stored in the sorted set with special name, so it could be found later by the value. For example with defined User model from the above code:

```ruby
user = User.new :first_name => "Robert", :last_name => "Pirsig"
user.save

# 2 redis keys are created "user:first_name:Robert" and "user:first_name:Robert:last_name:Pirsig" so we could search records like this:

User.find_by_first_name("Robert")                             # => user
User.find_all_by_first_name("Robert")                         # => [user]
User.find_by_first_name_and_last_name("Robert", "Pirsig")     # => user
User.find_all_by_first_name_and_last_name("Chris", "Pirsig")  # => []
```

Indices on associations are also created/deleted/updated when objects with has_many/belongs_to associations are created/deleted/updated (excerpt from association_indices_test.rb):

```ruby
class Article < RedisOrm::Base
  property :title, String
  has_many :comments
end

class Comment < RedisOrm::Base
  property :body, String
  property :moderated, RedisOrm::Boolean, :default => false
  index :moderated
  belongs_to :article
end

article = Article.create :title => "DHH drops OpenID on 37signals"
comment1 = Comment.create :body => "test"    
comment2 = Comment.create :body => "test #2", :moderated => true

article.comments << [comment1, comment2]

# here besides usual indices for each comment, 2 association indices are created so #find with *:conditions* on comments should work

article.comments.find(:all, :conditions => {:moderated => true})
article.comments.find(:all, :conditions => {:moderated => false})
```

Index definition supports following options:

*  **:unique** Boolean default: false

  If true is specified then value is stored in ordinary key-value structure with index as the key, otherwise the values are added to sorted set with index as the key and *Time.now.to_f* as a score.
  
*  **:case_insensitive** Boolean default: false

  If true is specified then property values are saved downcased (and then are transformed to downcase form when searching). Works for compound indices too.
  
## Associations

RedisOrm provides 3 association types:

* has_one

* has_many

* belongs_to

HABTM association could be emulated with 2 has_many declarations in related models.

### has_many/belongs_to associations

```ruby
class Article < RedisOrm::Base
  property :title, String
  has_many :comments
end

class Comment < RedisOrm::Base
  property :body, String
  belongs_to :article
end

article = Article.create :title => "DHH drops OpenID support on 37signals"
comment1 = Comment.create :body => "test"
comment2 = Comment.create :body => "test #2"

article.comments << [comment1, comment2]

# or rewrite associations
article.comments = [comment1, comment2]

article.comments # => [comment1, comment2]
comment1.article # => article
comment2.article # => article
```

Backlinks are automatically created.

### has_one/belongs_to associations

```ruby
class User < RedisOrm::Base
  property :name, String
  has_one :profile  
end

class Profile < RedisOrm::Base
  property :age, Integer
  
  validates_presence_of :age  
  belongs_to :user
end

user = User.create :name => "Haruki Murakami"
profile = Profile.create :age => 26
user.profile = profile

user.profile # => profile
profile.user # => user
```

Backlink is automatically created.

### has_many/has_many associations (HABTM)

```ruby
class Article < RedisOrm::Base
  property :title, String
  has_many :categories
end

class Category < RedisOrm::Base
  property :name, String
  has_many :articles
end

article = Article.create :title => "DHH drops OpenID support on 37signals"

cat1 = Category.create :name => "Nature"
cat2 = Category.create :name => "Art"
cat3 = Category.create :name => "Web"

article.categories << [cat1, cat2, cat3]

article.categories # => [cat1, cat2, cat3]
cat1.articles # => [article]
cat2.articles # => [article]
cat3.articles # => [article]
```

Backlinks are automatically created.

### Self-referencing association

```ruby
class User < RedisOrm::Base
  property :name, String
  index :name
  has_many :users, :as => :friends
end

me = User.create :name => "german"
friend1 = User.create :name => "friend1"
friend2 = User.create :name => "friend2"

me.friends << [friend1, friend2]

me.friends # => [friend1, friend2]
friend1.friends # => []
friend2.friends # => []
```

As an exception if *:as* option for the association is provided the backlinks aren't created.

### Polymorphic associations

Polymorphic associations work the same way they do in ActiveRecord (2 keys are created to store type and id of the record)

```ruby
class CatalogItem < RedisOrm::Base
  property :title, String

  belongs_to :resource, :polymorphic => true
end

class Book < RedisOrm::Base
  property :price, Integer
  property :title, String
  
  has_one :catalog_item
end

class Giftcard < RedisOrm::Base
  property :price, Integer
  property :title, String

  has_one :catalog_item
end

book = Book.create :title => "Permutation City", :author => "Egan Greg", :price => 1529
giftcard = Giftcard.create :title => "Happy New Year!"

ci1 = CatalogItem.create :title => giftcard.title
ci1.resource = giftcard
    
ci2 = CatalogItem.create :title => book.title
ci2.resource = book
```

All associations supports following options:

* *:as* 

  Symbol Association could be accessed by provided name

* *:dependent* 

  Symbol could be either :destroy or :nullify (default value)

### Clearing/reseting associations

You could clear/reset associations by assigning appropriately nil/[] to it:

```ruby
# has_many association
@article.comments << [@comment1, @comment2]
@article.comments.count # => 2
@comment1.article       # => @article

# clear    
@article.comments = []
@article.comments.count # => 0
@comment1.article       # => nil

# belongs_to (same for has_one)
@article.comments << [@comment1, @comment2]
@article.comments.count # => 2
@comment1.article       # => @article
    
# clear
@comment1.article = nil
@article.comments.count # => 1
@comment1.article       # => nil
```

For more examples please check test/associations_test.rb and test/polymorphic_test.rb

## Validation

RedisOrm includes ActiveModel::Validations. So all well-known validation callbacks are already in. An excerpt from test/validations_test.rb:

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

When saving object standard ActiveModel's #valid? method is invoked at first. Then appropriate callbacks are run. Then new Hash in Redis is created with keys/values equal to the properties/values of the saving object. 

The object's id is stored in "model_name:ids" sorted set with Time.now.to_f as a score. So records are ordered by created_at time by default. Then record's indices are created/updated.

## Dirty

Redis_orm also provides dirty methods to check whether the property has changed and what are these changes. To check it you could use 2 methods: #property_changed? (returns true or false) and #property_changes (returns array with changed values).

## File attachment management with paperclip and redis

[3 simple steps](http://def-end.com/post/6669884103/file-attachment-management-with-paperclip-and-redis) you should follow to manage your file attachments with redis and paperclip.

## Tests

Though I'm a big fan of the Test::Unit all tests are based on RSpec. And the only reason I use RSpec is possibility to define *before(:all)* and *after(:all)* hooks. So I could spawn/kill redis-server's process (from test_helper.rb):

```ruby
RSpec.configure do |config|
  config.before(:all) do
    path_to_conf = File.dirname(File.expand_path(__FILE__)) + "/redis.conf"
    $redis_pid = spawn 'redis-server ' + path_to_conf, :out => "/dev/null"
    sleep(0.3) # must be some delay otherwise "Connection refused - Unable to connect to Redis"
    path_to_socket = File.dirname(File.expand_path(__FILE__)) + "/../redis.sock"
    $redis = Redis.new(:host => 'localhost', :path => path_to_socket)
  end
  
  config.before(:each) do
    $redis.flushall if $redis
  end

  config.after(:each) do
   $redis.flushall if $redis
  end

  config.after(:all) do
    Process.kill 9, $redis_pid.to_i if $redis_pid
  end
end
```

To run all tests just invoke *rake test*

Copyright © 2011 Dmitrii Samoilov, released under the MIT license

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
