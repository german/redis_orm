require File.dirname(File.expand_path(__FILE__)) + '/test_helper.rb'

class User < RedisOrm::Base
  use_uuid_as_id
  
  property :name, String
  property :age, Integer
  property :wage, Float
  property :male, RedisOrm::Boolean

  property :created_at, Time
  property :modified_at, Time
  
  has_many :users, :as => :friends
end

class DefaultUser < RedisOrm::Base
  use_uuid_as_id
  
  property :name, String, :default => "german"
  property :age, Integer, :default => 26
  property :wage, Float, :default => 256.25
  property :male, RedisOrm::Boolean, :default => true
  property :admin, RedisOrm::Boolean, :default => false
  
  property :created_at, Time
  property :modified_at, Time
end

class TimeStamp < RedisOrm::Base
  use_uuid_as_id
  timestamps
end

describe "check basic functionality" do
  it "test_simple_creation" do
    User.count.should == 0

    user = User.new :name => "german"
    user.save

    user.should be
    user.id.should be
    
    user.id.should_not == 1
    user.id.length.should == 32 # b57525b09a69012e8fbe001d61192f09 for example
    
    user.name.should == "german"

    User.count.should == 1
    User.first.name.should == "german"
  end

  it "should test different ways to update a record" do
    User.count.should == 0

    user = User.new :name => "german"
    user.should be
    user.save

    user.name.should == "german"

    user.name = "nobody"
    user.save

    User.count.should == 1
    User.first.name.should == "nobody"

    u = User.first
    u.should be
    u.id.should_not == 1
    u.id.length.should == 32
    u.update_attribute :name, "root"
    User.first.name.should == "root"

    u = User.first
    u.should be
    u.update_attributes :name => "german"
    User.first.name.should == "german"
  end

  it "test_deletion" do
    User.count.should == 0

    user = User.new :name => "german"
    user.save
    user.should be

    user.name.should == "german"

    User.count.should == 1
    id = user.id
    
    user.destroy
    User.count.should == 0
    $redis.zrank("user:ids", id).should == nil
    $redis.hgetall("user:#{id}").should == {}
  end

  it "should return first and last objects" do
    User.count.should == 0
    User.first.should == nil
    User.last.should == nil

    user1 = User.new :name => "german"
    user1.save
    user1.should be
    user1.name.should == "german"
    user1.id.should_not == 1
    user1.id.length.should == 32 # b57525b09a69012e8fbe001d61192f09 for example
    
    user2 = User.new :name => "nobody"
    user2.save
    user2.should be
    user2.name.should == "nobody"
    user2.id.should_not == 2
    user2.id.length.should == 32
    
    User.count.should == 2

    User.first.should be
    User.last.should be

    User.first.id.should == user1.id
    User.last.id.should  == user2.id
  end

  it "should return values with correct classes" do
    user = User.new
    user.name = "german"
    user.age = 26
    user.wage = 124.34
    user.male = true
    user.save

    user.should be

    u = User.first

    u.created_at.class.should == Time
    u.modified_at.class.should == Time
    u.wage.class.should == Float
    u.male.class.to_s.should match(/TrueClass|FalseClass/)
    u.age.class.to_s.should match(/Integer|Fixnum/)
    u.id.should_not == 1
    u.id.length.should == 32
    
    u.name.should == "german"
    u.wage.should == 124.34
    u.age.should  == 26
    u.male.should == true
  end

  it "should return correct saved defaults" do
    DefaultUser.count.should == 0
    DefaultUser.create
    DefaultUser.count.should == 1

    u = DefaultUser.first

    u.created_at.class.should == Time
    u.modified_at.class.should == Time
    u.wage.class.should == Float
    u.male.class.to_s.should match(/TrueClass|FalseClass/)
    u.admin.class.to_s.should match(/TrueClass|FalseClass/)
    u.age.class.to_s.should match(/Integer|Fixnum/)

    u.name.should == "german"
    u.male.should == true
    u.age.should  == 26
    u.wage.should == 256.25
    u.admin.should == false
    u.id.should_not == 1
    u.id.length.should == 32
    
    du = DefaultUser.new
    du.name = "germaninthetown"
    du.save
    
    du_saved = DefaultUser.last
    du_saved.name.should == "germaninthetown"
    du_saved.admin.should == false
    du.id.should_not == 2
    du.id.should_not == u.id
    du.id.length.should == 32
  end
  
  it "should expand timestamps declaration properly" do
    t = TimeStamp.new
    t.save
    
    t.created_at.should be
    t.modified_at.should be
    t.created_at.day.should == Time.now.day
    t.modified_at.day.should == Time.now.day
  end
  
  # from associations_test.rb
  it "should maintain correct self referencing link" do
    me = User.create :name => "german", :age => 26, :wage => 10.0, :male => true
    friend1 = User.create :name => "friend1", :age => 26, :wage => 7.0, :male => true
    friend2 = User.create :name => "friend2", :age => 25, :wage => 5.0, :male => true

    me.friends << [friend1, friend2]

    me.friends.count.should == 2
    friend1.friends.count.should == 0
    friend2.friends.count.should == 0
  end
end
