require 'spec_helper'

describe "check indices for associations" do
  before(:each) do
    @article = Article.new :title => "DHH drops OpenID on 37signals"
    @article.save

    expect(@article).to be
    expect(@article.title).to eq("DHH drops OpenID on 37signals")

    @comment1 = Comment.new :body => "test"
    @comment1.save
    expect(@comment1).to be
    expect(@comment1.body).to eq("test")
    expect(@comment1.moderated).to eq(false)
    
    @comment2 = Comment.new :body => "test #2", :moderated => true
    @comment2.save
    expect(@comment2).to be
    expect(@comment2.body).to eq("test #2")
    expect(@comment2.moderated).to eq(true)
  end

  it "should properly find associated records (e.g. with :conditions, :order, etc options) '<<' used for association" do
    @article.comments << [@comment1, @comment2]
    expect(@article.comments.count).to eq(2)

    expect(@article.comments.all(:limit => 1).size).to eq(1)
    expect(@article.comments.find(:first)).to be
    expect(@article.comments.find(:first).id).to eq(@comment1.id)
    expect(@article.comments.find(:last)).to be
    expect(@article.comments.find(:last).id).to eq(@comment2.id)

    expect(@article.comments.find(:all, :conditions => {:moderated => true}).size).to eq(1)
    expect(@article.comments.find(:all, :conditions => {:moderated => false}).size).to eq(1)
    expect(@article.comments.find(:all, :conditions => {:moderated => true})[0].id).to eq(@comment2.id)
    expect(@article.comments.find(:all, :conditions => {:moderated => false})[0].id).to eq(@comment1.id)

    expect(@article.comments.find(:all, :conditions => {:moderated => true}, :limit => 1).size).to eq(1)
    expect(@article.comments.find(:all, :conditions => {:moderated => false}, :limit => 1).size).to eq(1)
    expect(@article.comments.find(:all, :conditions => {:moderated => true}, :limit => 1)[0].id).to eq(@comment2.id)
    expect(@article.comments.find(:all, :conditions => {:moderated => false}, :limit => 1)[0].id).to eq(@comment1.id)

    expect(@article.comments.find(:all, :conditions => {:moderated => true}, :limit => 1, :order => :desc).size).to eq(1)
    expect(@article.comments.find(:all, :conditions => {:moderated => false}, :limit => 1, :order => :asc).size).to eq(1)
    expect(@article.comments.find(:all, :conditions => {:moderated => true}, :limit => 1, :order => :desc)[0].id).to eq(@comment2.id)
    expect(@article.comments.find(:all, :conditions => {:moderated => false}, :limit => 1, :order => :asc)[0].id).to eq(@comment1.id)

    @comment1.update_attribute :moderated, true
    
    # expect(@article.comments.find(:all, :conditions => {:moderated => true}).size).to eq(2)
    # expect(@article.comments.find(:all, :conditions => {:moderated => false}).size).to eq(0)

    @comment1.destroy

    expect($redis.zrange("article:#{@article.id}:comments:moderated:true", 0, -1).size).to eq(1)
    expect($redis.zrange("article:#{@article.id}:comments:moderated:true", 0, -1)[0]).to eq(@comment2.id.to_s)
    # expect($redis.zrange("article:#{@article.id}:comments:moderated:false", 0, -1).size).to eq(0)
    expect(@article.comments.find(:all, :conditions => {:moderated => true}).size).to eq(1)
    expect(@article.comments.find(:all, :conditions => {:moderated => false}).size).to eq(0)
  end

  it "should properly find associated records (e.g. with :conditions, :order, etc options) '=' used for association" do
    @article.comments = [@comment1, @comment2]
    expect(@article.comments.count).to eq(2)
    
    expect(@article.comments.all(:limit => 1).size).to eq(1)
    expect(@article.comments.find(:first)).to be
    expect(@article.comments.find(:first).id).to eq(@comment1.id)
    expect(@article.comments.find(:last)).to be
    expect(@article.comments.find(:last).id).to eq(@comment2.id)
    
    expect(@article.comments.find(:all, :conditions => {:moderated => true}).size).to eq(1)
    expect(@article.comments.find(:all, :conditions => {:moderated => false}).size).to eq(1)
    expect(@article.comments.find(:all, :conditions => {:moderated => true})[0].id).to eq(@comment2.id)
    expect(@article.comments.find(:all, :conditions => {:moderated => false})[0].id).to eq(@comment1.id)
    
    expect(@article.comments.find(:all, :conditions => {:moderated => true}, :limit => 1).size).to eq(1)
    expect(@article.comments.find(:all, :conditions => {:moderated => false}, :limit => 1).size).to eq(1)
    expect(@article.comments.find(:all, :conditions => {:moderated => true}, :limit => 1)[0].id).to eq(@comment2.id)
    expect(@article.comments.find(:all, :conditions => {:moderated => false}, :limit => 1)[0].id).to eq(@comment1.id)
        
    expect(@article.comments.find(:all, :conditions => {:moderated => true}, :limit => 1, :order => :desc).size).to eq(1)
    expect(@article.comments.find(:all, :conditions => {:moderated => false}, :limit => 1, :order => :asc).size).to eq(1)
    expect(@article.comments.find(:all, :conditions => {:moderated => true}, :limit => 1, :order => :desc)[0].id).to eq(@comment2.id)
    expect(@article.comments.find(:all, :conditions => {:moderated => false}, :limit => 1, :order => :asc)[0].id).to eq(@comment1.id)
    
    @comment1.update_attribute :moderated, true
    expect(@article.comments.find(:all, :conditions => {:moderated => true}).size).to eq(2)
    expect(@article.comments.find(:all, :conditions => {:moderated => false}).size).to eq(0)
    
    @comment1.destroy
    expect(@article.comments.find(:all, :conditions => {:moderated => true}).size).to eq(1)
    expect(@article.comments.find(:all, :conditions => {:moderated => false}).size).to eq(0)
    expect($redis.zrange("article:#{@article.id}:comments:moderated:true", 0, -1).size).to eq(1)
    expect($redis.zrange("article:#{@article.id}:comments:moderated:true", 0, -1)[0]).to eq(@comment2.id.to_s)
    expect($redis.zrange("article:#{@article.id}:comments:moderated:false", 0, -1).size).to eq(0)
  end

  it "should check compound indices for associations" do
    friend1 = User.create :name => "Director", :moderator => true, :moderated_area => "films"
    friend2 = User.create :name => "Admin", :moderator => true, :moderated_area => "all"
    friend3 = User.create :name => "Gena", :moderator => false
    
    me = User.create :name => "german"
    
    me.friends << [friend1, friend2, friend3]
    
    expect(me.friends.count).to eq(3)
    expect(me.friends.find(:all, :conditions => {:moderator => true}).size).to eq(2)
    expect(me.friends.find(:all, :conditions => {:moderator => false}).size).to eq(1)
    
    expect(me.friends.find(:all, :conditions => {:moderator => true, :moderated_area => "films"}).size).to eq(1)
    expect(me.friends.find(:all, :conditions => {:moderator => true, :moderated_area => "films"})[0].id).to eq(friend1.id)

    # reverse key's order in :conditions hash
    expect(me.friends.find(:all, :conditions => {:moderated_area => "all", :moderator => true}).size).to eq(1)
    expect(me.friends.find(:all, :conditions => {:moderated_area => "all", :moderator => true})[0].id).to eq(friend2.id)
  end
  
  # TODO check that index assoc shouldn't be created while no assoc_record is provided

  it "should return first model if it exists, when conditions contain associated object" do
    user = User.create :name => "Dmitrii Samoilov", :age => 99, :wage => 35_000,
      :first_name => "Dmitrii", :last_name => "Samoilov"
    note = Note.create :body => "a test to test"
    note2 = Note.create :body => "aero"
    
    note.owner = user
    
    expect(User.count).to eq(1)
    expect(Note.count).to eq(2)
    expect($redis.zcard("note:owner:1")).to eq(1)    
    expect(note.owner).to eq(user)
    expect(Note.find(:all, :conditions => {:owner => user})).to eq([note])
    expect(Note.find(:first, :conditions => {:owner => user})).to eq(note)
    
    note.owner = nil
    expect(Note.find(:all, :conditions => {:owner => user})).to eq([])
    expect(Note.find(:first, :conditions => {:owner => user})).to eq(nil)
    expect($redis.zcard("note:owner:1")).to eq(0)
  end

  it "should return first model if it exists when conditions contain associated object (belongs_to assoc established when creating object)" do
    user = User.create :name => "Dmitrii Samoilov", :age => 99, :wage => 35_000,
      :first_name => "Dmitrii", :last_name => "Samoilov"
    note = Note.create :body => "a test to test", :owner => user
    Note.create :body => "aero" # just test what would *find* return if 2 exemplars of Note are created
    
    expect(User.count).to eq(1)
    expect(Note.count).to eq(2)

    expect(note.owner).to eq(user)
    
    expect(Note.find(:all, :conditions => {:owner => user})).to eq([note])
    expect(Note.find(:first, :conditions => {:owner => user})).to eq(note)
  end
  
  it "should return first model if it exists when conditions contain associated object (has_one assoc established when creating object)" do
    profile = Profile.create :title => "a test to test", :name => "german"
    user = User.create :name => "Dmitrii Samoilov", :age => 99, :wage => 35_000,
      :first_name => "Dmitrii", :last_name => "Samoilov", :profile => profile
    User.create :name => "Warren Buffet", :age => 399, :wage => 12_235_000, 
      :first_name => "Warren", :last_name => "Buffet"
    
    expect(User.count).to eq(2)
    expect(Profile.count).to eq(1)

    expect(profile.user).to eq(user)
    
    expect(User.find(:all, :conditions => {:profile => profile})).to eq([user])
    expect(User.find(:first, :conditions => {:profile => profile})).to eq(user)
  end
end
