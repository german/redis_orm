require File.dirname(File.expand_path(__FILE__)) + '/test_helper.rb'

class User < RedisOrm::Base
  property :name, String, :sortable => true
  property :age, Integer, :sortable => true
  property :wage, Float, :sortable => true
  
  property :address, String
  
  index :name
  index :age
end

class SortableUser < RedisOrm::Base
  property :name, String, :sortable => true
  index :name
end

describe "test options" do
  before(:each) do
    @dan     = User.create :name => "Daniel",   :age => 26, :wage => 40000.0,   :address => "Bellevue"
    @abe     = User.create :name => "Abe",      :age => 30, :wage => 100000.0,  :address => "Bellevue"
    @michael = User.create :name => "Michael",  :age => 25, :wage => 60000.0,   :address => "Bellevue"
    @todd    = User.create :name => "Todd",     :age => 22, :wage => 30000.0,   :address => "Bellevue"
  end

  it "should return records in specified order" do
    $redis.llen("user:name_ids").to_i.should == User.count
    $redis.zcard("user:age_ids").to_i.should == User.count
    $redis.zcard("user:wage_ids").to_i.should == User.count
    
    User.find(:all, :order => [:name, :asc]).should == [@abe, @dan, @michael, @todd]
    User.find(:all, :order => [:name, :desc]).should == [@todd, @michael, @dan, @abe]
    
    User.find(:all, :order => [:age, :asc]).should == [@todd, @michael, @dan, @abe]
    User.find(:all, :order => [:age, :desc]).should == [@abe, @dan, @michael, @todd]
    
    User.find(:all, :order => [:wage, :asc]).should == [@todd, @dan, @michael, @abe]
    User.find(:all, :order => [:wage, :desc]).should == [@abe, @michael, @dan, @todd]
  end

  it "should return records which met specified conditions in specified order" do
    @abe2    = User.create :name => "Abe",      :age => 12, :wage => 10.0,      :address => "Santa Fe"
    
    # :asc should be default value for property in :order clause
    User.find(:all, :conditions => {:name => "Abe"}, :order => [:wage]).should == [@abe2, @abe]
    
    User.find(:all, :conditions => {:name => "Abe"}, :order => [:wage, :desc]).should == [@abe, @abe2]
    User.find(:all, :conditions => {:name => "Abe"}, :order => [:wage, :asc]).should == [@abe2, @abe]
    
    User.find(:all, :conditions => {:name => "Abe"}, :order => [:age, :desc]).should == [@abe, @abe2]
    User.find(:all, :conditions => {:name => "Abe"}, :order => [:age, :asc]).should == [@abe2, @abe]
    
    User.find(:all, :conditions => {:name => "Abe"}, :order => [:wage, :desc]).should == [@abe, @abe2]
    User.find(:all, :conditions => {:name => "Abe"}, :order => [:wage, :asc]).should == [@abe2, @abe]
  end

  it "should update keys after the persisted object was edited and sort properly" do
    @abe.update_attributes :name => "Zed", :age => 12, :wage => 10.0, :address => "Santa Fe"

    $redis.llen("user:name_ids").to_i.should == User.count
    $redis.zcard("user:age_ids").to_i.should == User.count
    $redis.zcard("user:wage_ids").to_i.should == User.count

    User.find(:all, :order => [:name, :asc]).should == [@dan, @michael, @todd, @abe]
    User.find(:all, :order => [:name, :desc]).should == [@abe, @todd, @michael, @dan]
        
    User.find(:all, :order => [:age, :asc]).should == [@abe, @todd, @michael, @dan]
    User.find(:all, :order => [:age, :desc]).should == [@dan, @michael, @todd, @abe]
    
    User.find(:all, :order => [:wage, :asc]).should == [@abe, @todd, @dan, @michael]
    User.find(:all, :order => [:wage, :desc]).should == [@michael, @dan, @todd, @abe]
  end

  it "should update keys after the persisted object was deleted and sort properly" do
    user_count = User.count
    @abe.destroy

    $redis.llen("user:name_ids").to_i.should == user_count - 1
    $redis.zcard("user:age_ids").to_i.should == user_count - 1
    $redis.zcard("user:wage_ids").to_i.should == user_count - 1

    User.find(:all, :order => [:name, :asc]).should == [@dan, @michael, @todd]
    User.find(:all, :order => [:name, :desc]).should == [@todd, @michael, @dan]
        
    User.find(:all, :order => [:age, :asc]).should == [@todd, @michael, @dan]
    User.find(:all, :order => [:age, :desc]).should == [@dan, @michael, @todd]
    
    User.find(:all, :order => [:wage, :asc]).should == [@todd, @dan, @michael]
    User.find(:all, :order => [:wage, :desc]).should == [@michael, @dan, @todd]
  end

  it "should sort objects with more than 3-4 symbols" do
    vladislav = User.create :name => "Vladislav", :age => 19, :wage => 120.0
    vladimir = User.create :name => "Vladimir", :age => 22, :wage => 220.5
    vlad = User.create :name => "Vlad", :age => 29, :wage => 1200.0
    
    User.find(:all, :order => [:name, :desc], :limit => 3).should == [vladislav, vladimir, vlad]
    User.find(:all, :order => [:name, :desc], :limit => 2, :offset => 4).should == [@michael, @dan]
    User.find(:all, :order => [:name, :desc], :offset => 3).should == [@todd, @michael, @dan, @abe]
    User.find(:all, :order => [:name, :desc]).should == [vladislav, vladimir, vlad, @todd, @michael, @dan, @abe]

    User.find(:all, :order => [:name, :asc], :limit => 3, :offset => 4).should == [vlad, vladimir, vladislav]
    User.find(:all, :order => [:name, :asc], :offset => 3).should == [@todd, vlad, vladimir, vladislav]
    User.find(:all, :order => [:name, :asc], :limit => 3).should == [@abe, @dan, @michael]
    User.find(:all, :order => [:name, :asc]).should == [@abe, @dan, @michael, @todd, vlad, vladimir, vladislav]
  end

  it "should properly handle multiple users with almost the same names" do
    users = []
    20.times{|i| users << SortableUser.create(:name => "user#{i}") }
    SortableUser.all(:order => [:name, :asc]).should == users.sort{|n,m| n.name <=> m.name}
  end

  it "should properly handle multiple users with almost the same names (descending order)" do
    rev_users = []
    20.times{|i| rev_users << SortableUser.create(:name => "user#{i}") }
    SortableUser.all(:order => [:name, :desc]).should == rev_users.sort{|n,m| n.name <=> m.name}.reverse
  end
end
