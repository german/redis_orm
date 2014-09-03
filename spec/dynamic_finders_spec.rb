require 'spec_helper'

describe "check associations" do
  it "should create and use indexes to implement dynamic finders" do
    user1 = DynamicFinderUser.new
    user1.first_name = "Dmitrii"
    user1.last_name = "Samoilov"
    user1.save

    DynamicFinderUser.find_by_first_name("John").should == nil

    user = DynamicFinderUser.find_by_first_name "Dmitrii"
    user.id.should == user1.id

    DynamicFinderUser.find_all_by_first_name("Dmitrii").size.should == 1

    user = DynamicFinderUser.find_by_first_name_and_last_name('Dmitrii', 'Samoilov')
    user.should be
    user.id.should == user1.id

    DynamicFinderUser.find_all_by_first_name_and_last_name('Dmitrii', 'Samoilov').size.should == 1

    DynamicFinderUser.find_all_by_last_name_and_first_name('Samoilov', 'Dmitrii')[0].id.should == user1.id

    lambda{DynamicFinderUser.find_by_first_name_and_cast_name('Dmitrii', 'Samoilov')}.should raise_error
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

  # TODO
  it "should properly delete indices when record was deleted" do
    
  end
end
