require File.dirname(File.expand_path(__FILE__)) + '/test_helper.rb'

describe "check basic functionality" do
  it "test_simple_creation" do
    UuidUser.count.should == 0

    user = UuidUser.new :name => "german"
    user.save

    user.should be
    user.id.should be
    
    user.id.should_not == 1
    user.id.length.should == 32 # b57525b09a69012e8fbe001d61192f09 for example
    
    user.name.should == "german"

    UuidUser.count.should == 1
    UuidUser.first.name.should == "german"
  end

  it "should test different ways to update a record" do
    UuidUser.count.should == 0

    user = UuidUser.new :name => "german"
    user.should be
    user.save

    user.name.should == "german"

    user.name = "nobody"
    user.save

    UuidUser.count.should == 1
    UuidUser.first.name.should == "nobody"

    u = UuidUser.first
    u.should be
    u.id.should_not == 1
    u.id.length.should == 32
    u.update_attribute :name, "root"
    UuidUser.first.name.should == "root"

    u = UuidUser.first
    u.should be
    u.update_attributes :name => "german"
    UuidUser.first.name.should == "german"
  end

  it "test_deletion" do
    UuidUser.count.should == 0

    user = UuidUser.new :name => "german"
    user.save
    user.should be

    user.name.should == "german"

    UuidUser.count.should == 1
    id = user.id
    
    user.destroy
    UuidUser.count.should == 0
    $redis.zrank("user:ids", id).should == nil
    $redis.hgetall("user:#{id}").should == {}
  end

  it "should return first and last objects" do
    UuidUser.count.should == 0
    UuidUser.first.should == nil
    UuidUser.last.should == nil

    user1 = UuidUser.new :name => "german"
    user1.save
    user1.should be
    user1.name.should == "german"
    user1.id.should_not == 1
    user1.id.length.should == 32 # b57525b09a69012e8fbe001d61192f09 for example
    
    user2 = UuidUser.new :name => "nobody"
    user2.save
    user2.should be
    user2.name.should == "nobody"
    user2.id.should_not == 2
    user2.id.length.should == 32
    
    UuidUser.count.should == 2

    UuidUser.first.should be
    UuidUser.last.should be

    UuidUser.first.id.should == user1.id
    UuidUser.last.id.should  == user2.id
  end

  it "should return values with correct classes" do
    user = UuidUser.new
    user.name = "german"
    user.age = 26
    user.wage = 124.34
    user.male = true
    user.save

    user.should be

    u = UuidUser.first

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
    UuidDefaultUser.count.should == 0
    UuidDefaultUser.create
    UuidDefaultUser.count.should == 1

    u = UuidDefaultUser.first

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
    
    du = UuidDefaultUser.new
    du.name = "germaninthetown"
    du.save
    
    du_saved = UuidDefaultUser.last
    du_saved.name.should == "germaninthetown"
    du_saved.admin.should == false
    du.id.should_not == 2
    du.id.should_not == u.id
    du.id.length.should == 32
  end
  
  it "should expand timestamps declaration properly" do
    t = UuidTimeStamp.new
    t.save
    
    t.created_at.should be
    t.modified_at.should be
    t.created_at.day.should == Time.now.day
    t.modified_at.day.should == Time.now.day
  end
  
  # from associations_test.rb
  it "should maintain correct self referencing link" do
    me = UuidUser.create :name => "german", :age => 26, :wage => 10.0, :male => true
    friend1 = UuidUser.create :name => "friend1", :age => 26, :wage => 7.0, :male => true
    friend2 = UuidUser.create :name => "friend2", :age => 25, :wage => 5.0, :male => true

    me.friends << [friend1, friend2]

    me.friends.count.should == 2
    friend1.friends.count.should == 0
    friend2.friends.count.should == 0
  end
end
