require File.dirname(File.expand_path(__FILE__)) + '/test_helper.rb'

describe "check basic functionality" do
  it "should have 3 models in descendants" do
    RedisOrm::Base.descendants.should include(User, DefaultUser, TimeStamp)
    RedisOrm::Base.descendants.should_not include(EmptyPerson)
  end
  
  it "should return the same user" do
    user = User.new :name => "german"
    user.save
    User.first.should == user
    
    user.name = "Anderson"
    User.first.should_not == user
  end
  
  it "test_simple_creation" do
    User.count.should == 0

    user = User.new :name => "german"
    user.save

    user.should be

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

    user2 = User.new :name => "nobody"
    user2.save
    user2.should be
    user2.name.should == "nobody"

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
    
    du = DefaultUser.new
    du.name = "germaninthetown"
    du.save
    
    du_saved = DefaultUser.last
    du_saved.name.should == "germaninthetown"
    du_saved.admin.should == false
  end
  
  it "should expand timestamps declaration properly" do
    t = TimeStamp.new
    t.save
    
    t.created_at.should be
    t.modified_at.should be
    t.created_at.day.should == Time.now.day
    t.modified_at.day.should == Time.now.day
  end

  it "should properly transform :default values to right classes (if :default values are wrong) so when comparing them to other/stored instances they'll be the same" do
    # SortableUser class has 3 properties with wrong classes of :default value
    u = SortableUser.new :name => "Alan"
    u.save
    
    su = SortableUser.first
    su.test_type_cast.should == false
    su.wage.should == 20_000.0
    su.age.should == 26
  end
end
