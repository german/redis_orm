require File.dirname(File.expand_path(__FILE__)) + '/test_helper.rb'

class Photo < RedisOrm::Base
  property :image, String
  
  validates_presence_of :image
  validates_length_of :image, :in => 7..32
  validates_format_of :image, :with => /\w*\.(gif|jpe?g|png)/
end

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
