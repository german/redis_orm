require 'spec_helper'

describe "check associations" do
  it "should return correct _changes array" do
    user = User.new :name => "german"
    user.name_changed?.should == false
    
    user.name_changes.should == ["german"]
    user.save
    
    user.name_changes.should == ["german"]
    user.name = "germaninthetown"
    user.name_changes.should == ["german", "germaninthetown"]
    user.name_changed?.should == true
    user.save

    user = User.first
    user.name.should == "germaninthetown"
    user.name_changed?.should == false
    user.name_changes.should == ["germaninthetown"]
    user.name = "german"
    user.name_changed?.should == true
    user.name_changes.should == ["germaninthetown", "german"]
  end
end
