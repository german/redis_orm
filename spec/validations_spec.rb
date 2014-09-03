require 'spec_helper'

describe "check associations" do
  it "should validate presence if image in photo" do
    p = Photo.new
    p.save.should == false
    p.errors.should be
    p.errors[:image].should include("can't be blank")

    p.image = "test"
    p.save.should == false
    p.errors.should be
    p.errors[:image].should include("is too short (minimum is 7 characters)")
    p.errors[:image].should include("is invalid")

    p.image = "facepalm.jpg"
    p.save
    p.errors.empty?.should == true
  end
end
