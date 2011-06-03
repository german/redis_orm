require 'rspec'
require File.dirname(File.expand_path(__FILE__)) + '/../lib/redis_orm.rb'

class CatalogItem < RedisOrm::Base
  property :title, String

  belongs_to :resource, :polymorphic => true
end

class Book < RedisOrm::Base
  property :price, Integer, :default => 0 # in cents
  property :title, String
  
  has_one :catalog_item
end

class Giftcard < RedisOrm::Base
  property :price, Integer, :default => 0 # in cents
  property :title, String

  has_one :catalog_item
end

# for second test
class Person < RedisOrm::Base
  property :name, String
  
  belongs_to :location, :polymorphic => true
end

class Country < RedisOrm::Base
  property :name, String

  has_many :people
end

class City < RedisOrm::Base
  property :name, String

  has_many :people
end

describe "check polymorphic property" do
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

  it "should provide proper associations and save records correctly for has_one/belongs_to polymorphic" do
    book = Book.new :title => "Permutation City", :author => "Egan Greg", :price => 1529
    book.save

    giftcard = Giftcard.create :title => "Happy New Year!"

    ci1 = CatalogItem.create :title => giftcard.title
    ci1.resource = giftcard
    
    ci2 = CatalogItem.create :title => book.title
    ci2.resource = book
    
    CatalogItem.count.should == 2
    [ci1, ci2].collect{|ci| ci.title}.should == [giftcard.title, book.title]
    
    ci1.resource.title.should == giftcard.title
    ci2.resource.title.should == book.title
    
    Book.first.catalog_item.should be
    Book.first.catalog_item.id.should == ci2.id
    
    Giftcard.first.catalog_item.should be
    Giftcard.first.catalog_item.id.should == ci1.id
  end
  
  it "should provide proper associations and save records correctly for has_many/belongs_to polymorphic" do
    country = Country.create :name => "Ukraine"
    city = City.create :name => "Lviv"
    
    person = Person.create :name => "german"
    person.location = country
    
    Person.first.location.id.should == country.id
    City.first.people.count.should == 0
    Country.first.people.count.should == 1
    Country.first.people[0].id.should == person.id
    
    person = Person.first
    person.location = city
    
    Person.first.location.id.should == city.id
    City.first.people.count.should == 1
    City.first.people[0].id.should == person.id
    Country.first.people.count.should == 0
  end
end
