require File.dirname(File.expand_path(__FILE__)) + '/test_helper.rb'

class User < RedisOrm::Base
  property :name, String
  property :age, Integer
  property :created_at, Time

  has_one :profile
end

class Profile < RedisOrm::Base
  property :title, String
  belongs_to :user
end

class Jigsaw < RedisOrm::Base
  property :title, String
  belongs_to :user
end

describe "exceptions test" do
  it "should raise an exception if association is provided with improper class" do
    User.count.should == 0

    user = User.new
    user.name = "german"
    user.save

    user.should be
    user.name.should == "german"
    User.count.should == 1

    jigsaw = Jigsaw.new
    jigsaw.title = "123"
    jigsaw.save

    # RedisOrm::TypeMismatchError
    lambda { user.profile = jigsaw }.should raise_error
  end   
end
