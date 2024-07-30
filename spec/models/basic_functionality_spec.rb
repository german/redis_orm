require 'spec_helper.rb'

describe "check basic functionality" do
  it "should have 3 models in descendants" do
    RedisOrm::Base.descendants.should include(User, DefaultUser, TimeStamp)
    RedisOrm::Base.descendants.should_not include(EmptyPerson)
  end
  
  it "should return the same user" do
    user = User.new :name => "german"
    user.save
    User.first.should == user
    
    user.name = "Anderson"
    User.first.should_not == user
  end

  it "test_simple_creation" do
    User.count.should == 0

    user = User.new :name => "german"
    
    user.save

    user.should be

    user.name.should == "german"
    user.__redis_record_key.should == "User:1"

    User.count.should == 1
    User.first.name.should == "german"
  end

  it "should test different ways to update a record" do
    User.count.should == 0

    user = User.new name: "german"
    user.should be
    user.save

    user.name.should == "german"

    user.name = "nobody"
    user.save

    User.count.should == 1
    User.first.name.should == "nobody"

    u = User.first
    expect(u).to be
    u.update_attribute :name, "root"
    User.first.name.should == "root"

    u = User.first
    u.should be
    u.update_attributes name: "german"
    User.first.name.should == "german"
  end

  it "test_deletion" do
    User.count.should == 0

    user = User.new :name => "german"
    user.save
    user.should be

    user.name.should == "german"

    User.count.should == 1
    id = user.id
    
    user.destroy
    User.count.should == 0
    $redis.zrank("user:ids", id).should == nil
    $redis.hgetall("user:#{id}").should == {}
  end

  it "should return first and last objects" do
    User.count.should == 0
    User.first.should == nil
    User.last.should == nil

    user1 = User.new :name => "german"
    user1.save
    user1.should be
    user1.name.should == "german"

    user2 = User.new :name => "nobody"
    user2.save
    user2.should be
    user2.name.should == "nobody"

    User.count.should == 2

    User.first.should be
    User.last.should be

    User.first.id.should == user1.id
    User.last.id.should  == user2.id
  end

  it "should return values with correct classes" do
    user = User.new
    user.name = "german"
    user.age = 26
    user.wage = 124.34
    user.male = true
    user.save

    user.should be

    u = User.first

    u.created_at.class.should == Time
    u.modified_at.class.should == Time
    u.wage.class.should == Float
    u.male.class.to_s.should match(/TrueClass|FalseClass/)
    u.age.class.to_s.should match(/Integer|Fixnum/)

    u.name.should == "german"
    u.wage.should == 124.34
    u.age.should  == 26
    u.male.should == true
  end

  it "should return correct saved defaults" do
    expect{
      DefaultUser.create
    }.to change(DefaultUser, :count)

    u = DefaultUser.first
    expect(u.wage.class).to eq(Float)

    u.male.class.to_s.should match(/TrueClass|FalseClass/)
    u.admin.class.to_s.should match(/TrueClass|FalseClass/)
    u.age.class.to_s.should match(/Integer|Fixnum/)

    expect(u.name).to eq("german")
    expect(u.male).to eq(true)
    expect(u.age).to eq(26)
    expect(u.wage).to eq(256.25)
    expect(u.admin).to eq(false)
    
    du = DefaultUser.new
    du.name = "germaninthetown"
    du.save
    du_saved = DefaultUser.last
    
    expect(du_saved.name).to eq("germaninthetown")
    expect(du_saved.admin).to eq(false)
  end

  it "should expand timestamps declaration properly" do
    t = TimeStamp.new
    t.save
    expect(t.created_at).to be
    expect(t.modified_at).to be
    expect(t.created_at.day).to eq(Time.now.day)
    expect(t.modified_at.day).to eq(Time.now.day)
  end

  it "should store arrays in the property correctly" do
    a = ArticleWithComments.new :title => "Article #1", :comments => ["Hello", "there are comments"]
    expect {
      a.save
    }.to change(ArticleWithComments, :count).by(1)
    
    saved_article = ArticleWithComments.last
    saved_article.comments.should == ["Hello", "there are comments"]
  end

  it "should store default hash in the property if it's not provided" do
    a = ArticleWithComments.new :title => "Article #1"
    expect {
      a.save
    }.to change(ArticleWithComments, :count).by(1)
    
    saved_article = ArticleWithComments.last
    expect(saved_article.rates).to eq({'1'=>0, '2'=>0, '3'=>0, '4' => 0, '5'=> 0})
  end
  
  it "should store hash in the property correctly" do
    a = ArticleWithComments.new(title: "Article #1", rates: {'4': 134})
    expect {
      a.save
    }.to change(ArticleWithComments, :count).by(1)
    
    saved_article = ArticleWithComments.last
    expect(saved_article.rates).to eql({'4' => 134})
  end
  
  it "should properly transform :default values to right classes (if :default values are wrong) so when comparing them to other/stored instances they'll be the same" do
    # SortableUser class has 3 properties with wrong classes of :default value
    u = SortableUser.new :name => "Alan"
    u.save
    
    su = SortableUser.first
    su.test_type_cast.should == false
    su.wage.should == 20_000.0
    su.age.should == 26
  end
end
