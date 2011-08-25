require File.dirname(File.expand_path(__FILE__)) + '/test_helper.rb'

class User < RedisOrm::Base
  property :name, String, :sortable => true
  property :age, Integer, :sortable => true
  property :wage, Float, :sortable => true
  
  property :address, String
  
  index :name
  index :age
end

describe "test options" do
  before(:each) do
    @dan     = User.create :name => "Daniel",   :age => 26, :wage => 40000.0,   :address => "Bellevue"
    @abe     = User.create :name => "Abe",      :age => 30, :wage => 100000.0,  :address => "Bellevue"
    @michael = User.create :name => "Michael",  :age => 25, :wage => 60000.0,   :address => "Bellevue"
    @todd    = User.create :name => "Todd",     :age => 22, :wage => 30000.0,   :address => "Bellevue"
  end
  
  it "should return records in specified order" do
    $redis.zcard("user:name_ids").to_i.should == User.count
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
end
