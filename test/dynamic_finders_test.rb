require File.dirname(File.expand_path(__FILE__)) + '/test_helper.rb'

class User < RedisOrm::Base
  property :first_name, String
  property :last_name, String

  index :first_name, :unique => true
  index :last_name,  :unique => true
  index [:first_name, :last_name], :unique => false
end

class CustomUser < RedisOrm::Base
  property :first_name, String
  property :last_name, String

  index :first_name, :unique => false
  index :last_name,  :unique => false
  index [:first_name, :last_name], :unique => true
end

describe "check associations" do
  it "should create and use indexes to implement dynamic finders" do
    user1 = User.new
    user1.first_name = "Dmitrii"
    user1.last_name = "Samoilov"
    user1.save

    User.find_by_first_name("John").should == nil

    user = User.find_by_first_name "Dmitrii"
    user.id.should == user1.id

    User.find_all_by_first_name("Dmitrii").size.should == 1

    user = User.find_by_first_name_and_last_name('Dmitrii', 'Samoilov')
    user.should be
    user.id.should == user1.id

    User.find_all_by_first_name_and_last_name('Dmitrii', 'Samoilov').size.should == 1

    lambda{User.find_all_by_last_name_and_first_name('Samoilov', 'Dmitrii')}.should raise_error

    lambda{User.find_by_first_name_and_cast_name('Dmitrii', 'Samoilov')}.should raise_error
  end

  it "should create and use indexes to implement dynamic finders" do
    user1 = CustomUser.new
    user1.first_name = "Dmitrii"
    user1.last_name = "Samoilov"
    user1.save

    user2 = CustomUser.new
    user2.first_name = "Dmitrii"
    user2.last_name = "Nabaldyan"
    user2.save

    user = CustomUser.find_by_first_name "Dmitrii"
    user.id.should == user1.id

    CustomUser.find_by_last_name("Krassovkin").should == nil

    CustomUser.find_all_by_first_name("Dmitrii").size.should == 2
  end

  it "should properly delete indices when record was deleted" do
    
  end
end
