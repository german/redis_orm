require File.dirname(File.expand_path(__FILE__)) + '/test_helper.rb'

describe "exceptions test" do
  it "should raise an exception if association is provided with improper class" do
    User.count.should == 0

    user = User.new :name => "german", :age => 26
    user.save

    user.should be
    user.name.should == "german"
    User.count.should == 1

    lambda{ User.find :all, :conditions => {:gender => true} }.should raise_error
    User.find(:all, :conditions => {:age => 26}).size.should == 1
    lambda{ User.find :all, :conditions => {:name => "german", :age => 26} }.should raise_error
    
    jigsaw = Jigsaw.new
    jigsaw.title = "123"
    jigsaw.save

    # RedisOrm::TypeMismatchError
    lambda { user.profile = jigsaw }.should raise_error
  end
  
  it "should raise an exception if there is no such record in the storage" do
    User.find(12).should == nil
    lambda{ User.find! 12 }.should raise_error(RedisOrm::RecordNotFound)
  end

  it "should throw an exception if there was an error while creating object with #create! method" do
    jigsaw = Jigsaw.create :title => "jigsaw"
    lambda { User.create!(:name => "John", :age => 44, :profile => jigsaw) }.should raise_error(RedisOrm::TypeMismatchError)
  end
end
