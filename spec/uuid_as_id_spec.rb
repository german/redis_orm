require 'spec_helper'

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

    u.created_at.class.should == DateTime
    u.modified_at.class.should == DateTime
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
    expect(UuidDefaultUser.count).to be(0)
    UuidDefaultUser.create
    expect(UuidDefaultUser.count).to be(1)

    u = UuidDefaultUser.first
    expect(u.created_at.class).to be(DateTime)
    expect(u.modified_at.class).to be(DateTime)
    expect(u.wage.class).to be(Float)
    expect(u.male.class.to_s).to match(/TrueClass|FalseClass/)
    expect(u.admin.class.to_s).to match(/TrueClass|FalseClass/)
    expect(u.age.class.to_s).to match(/Integer|Fixnum/)

    expect(u.name).to eq("german")
    expect(u.male).to be(true)
    expect(u.age).to be(26)
    expect(u.wage).to be(256.25)
    expect(u.admin).to be(false)
    expect(u.id).not_to be(1)
    expect(u.id.length).to be(32)
    
    du = UuidDefaultUser.new
    du.name = "germaninthetown"
    expect(du.save).to be_truthy
    expect(du.name).to eq("germaninthetown")

    expect(UuidDefaultUser.count).to be(2)

    du_last = UuidDefaultUser.last
    expect(du_last.name).to eq("germaninthetown")

    expect(du_last.admin).to be_falsey
    expect(du.id).not_to be(2)
    expect(du.id).not_to be(u.id)
    expect(du.id.length).to be(32)
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
