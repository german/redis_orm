require 'spec_helper.rb'

describe "exceptions test" do
  it "should raise an exception if association is provided with improper class" do
    expect(User.count).to eq(0)

    user = User.new :name => "german", :age => 26
    user.save

    expect(user).to be
    expect(user.name).to eq("german")
    expect(User.count).to eq(1)

    expect(lambda{ User.find :all, :conditions => {:gender => true} }).to raise_error(RedisOrm::NotIndexFound)
    expect(User.find(:all, :conditions => {:age => 26}).size).to eq(1)
    expect(lambda{ User.find :all, :conditions => {:name => "german", :age => 26} }).to raise_error(RedisOrm::NotIndexFound)
    
    jigsaw = Jigsaw.new
    jigsaw.title = "123"
    jigsaw.save

    expect(lambda { user.profile = jigsaw }).to raise_error(RedisOrm::TypeMismatchError)
  end
  
  it "should raise an exception if there is no such record in the storage" do
    expect(User.find(12)).to be_nil
    expect(lambda{ User.find! 12 }).to raise_error(RedisOrm::RecordNotFound)
  end

  it "should throw an exception if there was an error while creating object with #create! method" do
    jigsaw = Jigsaw.create :title => "jigsaw"
    expect(lambda { User.create!(:name => "John", :age => 44, :profile => jigsaw) }).to raise_error(RedisOrm::TypeMismatchError)
  end

  it "should throw an exception if wrong format of the default value is specified for Array/Hash property" do
    a = ArticleWithComments.new :title => "Article #1", :rates => [1,2,3,4,5]
    expect(lambda {
      a.save
    }).to raise_error(RedisOrm::TypeMismatchError)
    
    a = ArticleWithComments.new :title => "Article #1", :comments => 12
    expect(lambda {
      a.save
    }).to raise_error(RedisOrm::TypeMismatchError)
  end
end
