require 'spec_helper.rb'

describe "test options" do
  before(:each) do
    @dan = SortableUser.create name: "Daniel", age: 26, wage: 40000.0, address: "Bellevue"
    @abe = SortableUser.create name: "Abe", age: 30, wage: 100000.0, address: "Bellevue"
    @michael = SortableUser.create name: "Michael", age: 25, wage: 60000.0, address: "Bellevue"
    @todd = SortableUser.create name: "Todd", age: 22, wage: 30000.0, address: "Bellevue"
  end

  it "should return records in specified order" do
    expect($redis.llen("sortable_user:name_ids").to_i).to eq(SortableUser.count)
    expect($redis.zcard("sortable_user:age_ids").to_i).to eq(SortableUser.count)
    expect($redis.zcard("sortable_user:wage_ids").to_i).to eq(SortableUser.count)
    
    expect(SortableUser.find(:all, order: [:name, :asc])).to eq([@abe, @dan, @michael, @todd])
    expect(SortableUser.find(:all, order: [:name, :desc])).to eq([@todd, @michael, @dan, @abe])
    
    expect(SortableUser.find(:all, order: [:age, :asc])).to eq([@todd, @michael, @dan, @abe])
    expect(SortableUser.find(:all, order: [:age, :desc])).to eq([@abe, @dan, @michael, @todd])
    
    expect(SortableUser.find(:all, order: [:wage, :asc])).to eq([@todd, @dan, @michael, @abe])
    expect(SortableUser.find(:all, order: [:wage, :desc])).to eq([@abe, @michael, @dan, @todd])
  end

  it "should return records which met specified conditions in specified order" do
    @abe2 = SortableUser.create name: "Abe", age: 12, wage: 10.0, address: "Santa Fe"
    
    # :asc should be default value for property in :order clause
    expect(SortableUser.find(:all, conditions: {name: "Abe"}, order: [:wage])).to eq([@abe2, @abe])
    
    expect(SortableUser.find(:all, conditions: {name: "Abe"}, order: [:wage, :desc])).to eq([@abe, @abe2])
    expect(SortableUser.find(:all, conditions: {name: "Abe"}, order: [:wage, :asc])).to eq([@abe2, @abe])
    
    expect(SortableUser.find(:all, conditions: {name: "Abe"}, order: [:age, :desc])).to eq([@abe, @abe2])
    expect(SortableUser.find(:all, conditions: {name: "Abe"}, order: [:age, :asc])).to eq([@abe2, @abe])
    
    expect(SortableUser.find(:all, conditions: {name: "Abe"}, order: [:wage, :desc])).to eq([@abe, @abe2])
    expect(SortableUser.find(:all, conditions: {name: "Abe"}, order: [:wage, :asc])).to eq([@abe2, @abe])
  end

  it "should update keys after the persisted object was edited and sort properly" do
    @abe.update_attributes :name => "Zed", :age => 12, :wage => 10.0, :address => "Santa Fe"

    expect($redis.llen("sortable_user:name_ids").to_i).to eq(SortableUser.count)
    expect($redis.zcard("sortable_user:age_ids").to_i).to eq(SortableUser.count)
    expect($redis.zcard("sortable_user:wage_ids").to_i).to eq(SortableUser.count)

    expect(SortableUser.find(:all, order: [:name, :asc])).to eq([@dan, @michael, @todd, @abe])
    expect(SortableUser.find(:all, order: [:name, :desc])).to eq([@abe, @todd, @michael, @dan])
        
    expect(SortableUser.find(:all, order: [:age, :asc])).to eq([@abe, @todd, @michael, @dan])
    expect(SortableUser.find(:all, order: [:age, :desc])).to eq([@dan, @michael, @todd, @abe])
    
    expect(SortableUser.find(:all, order: [:wage, :asc])).to eq([@abe, @todd, @dan, @michael])
    expect(SortableUser.find(:all, order: [:wage, :desc])).to eq([@michael, @dan, @todd, @abe])
  end

  it "should update keys after the persisted object was deleted and sort properly" do
    user_count = SortableUser.count
    @abe.destroy

    expect($redis.llen("sortable_user:name_ids").to_i).to eq(user_count - 1)
    expect($redis.zcard("sortable_user:age_ids").to_i).to eq(user_count - 1)
    expect($redis.zcard("sortable_user:wage_ids").to_i).to eq(user_count - 1)

    expect(SortableUser.find(:all, order: [:name, :asc])).to eq([@dan, @michael, @todd])
    expect(SortableUser.find(:all, order: [:name, :desc])).to eq([@todd, @michael, @dan])
        
    expect(SortableUser.find(:all, order: [:age, :asc])).to eq([@todd, @michael, @dan])
    expect(SortableUser.find(:all, order: [:age, :desc])).to eq([@dan, @michael, @todd])
    
    expect(SortableUser.find(:all, order: [:wage, :asc])).to eq([@todd, @dan, @michael])
    expect(SortableUser.find(:all, order: [:wage, :desc])).to eq([@michael, @dan, @todd])
  end

  it "should sort objects with more than 3-4 symbols" do
    vladislav = SortableUser.create name: "Vladislav", age: 19, wage: 120.0
    vladimir = SortableUser.create name: "Vladimir", age: 22, wage: 220.5
    vlad = SortableUser.create name: "Vlad", age: 29, wage: 1200.0
    
    expect(SortableUser.find(:all, order: [:name, :desc], limit: 3)).to eq([vladislav, vladimir, vlad])
    expect(SortableUser.find(:all, order: [:name, :desc], limit: 2, offset: 4)).to eq([@michael, @dan])
    expect(SortableUser.find(:all, order: [:name, :desc], offset: 3)).to eq([@todd, @michael, @dan, @abe])
    expect(SortableUser.find(:all, order: [:name, :desc])).to eq([vladislav, vladimir, vlad, @todd, @michael, @dan, @abe])

    expect(SortableUser.find(:all, order: [:name, :asc], limit: 3, offset: 4)).to eq([vlad, vladimir, vladislav])
    expect(SortableUser.find(:all, order: [:name, :asc], offset: 3)).to eq([@todd, vlad, vladimir, vladislav])
    expect(SortableUser.find(:all, order: [:name, :asc], limit: 3)).to eq([@abe, @dan, @michael])
    expect(SortableUser.find(:all, order: [:name, :asc])).to eq([@abe, @dan, @michael, @todd, vlad, vladimir, vladislav])
  end

  it "should properly handle multiple users with almost the same names" do
    users = [@abe, @todd, @michael, @dan]
    20.times{|i| users << SortableUser.create(name: "user#{i}") }
    expect(users.sort_by(&:name)).to eq(SortableUser.all(order: [:name, :asc]))
  end

  it "should properly handle multiple users with almost the same names (descending order)" do
    rev_users = [@abe, @todd, @michael, @dan]
    20.times{|i| rev_users << SortableUser.create(name: "user#{i}") }
    expect(SortableUser.all(order: [:name, :desc])).to eq(rev_users.sort_by(&:name).reverse)
  end

  it "should properly store records with the same names" do
    users = [@abe, @todd, @michael, @dan]

    users << SortableUser.create(name: "user#1")
    users << SortableUser.create(name: "user#2")
    users << SortableUser.create(name: "user#1")
    users << SortableUser.create(name: "user#2")

    # we pluck only *name* here since it didn't sort by id (and it could be messed up)
    expect(SortableUser.all(order: [:name, :desc]).map{|u| u.name}).to eq(users.sort_by(&:name).map{|u| u.name}.reverse)
    expect(SortableUser.all(order: [:name, :asc]).map{|u| u.name}).to eq(users.sort_by(&:name).map{|u| u.name})
  end
end
