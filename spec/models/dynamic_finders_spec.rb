require 'spec_helper.rb'

describe "check associations" do
  class DynamicFinderUser < RedisOrm::Base
    property :first_name, String
    property :last_name, String

    index :first_name, :unique => true
    index :last_name,  :unique => true
    index [:first_name, :last_name], :unique => false
  end

  it "should create and use indexes to implement dynamic finders" do
    user1 = DynamicFinderUser.new
    user1.first_name = "Dmitrii"
    user1.last_name = "Samoilov"
    user1.save

    expect(DynamicFinderUser.find_by_first_name("John")).to be_nil

    user = DynamicFinderUser.find_by_first_name "Dmitrii"
    expect(user.id).to eq(user1.id)

    expect(DynamicFinderUser.find_all_by_first_name("Dmitrii").size).to eq(1)

    user = DynamicFinderUser.find_by_first_name_and_last_name('Dmitrii', 'Samoilov')
    expect(user).to be
    expect(user.id).to eq(user1.id)

    expect(DynamicFinderUser.find_all_by_first_name_and_last_name('Dmitrii', 'Samoilov').size).to eq(1)
    expect(DynamicFinderUser.find_all_by_last_name_and_first_name('Samoilov', 'Dmitrii')[0].id).to eq(user1.id)

    expect(
      lambda{DynamicFinderUser.find_by_first_name_and_err_name('Dmitrii', 'Samoilov')}
    ).to raise_error(RedisOrm::NotIndexFound)
  end

  it "should create and use indexes to implement dynamic finders" do
    user1 = CustomUser.new
    user1.first_name = "Dmitrii"
    user1.last_name = "Samoilov"
    user1.save

    user2 = CustomUser.new
    user2.first_name = "Dmitrii"
    user2.last_name = "Nabaldyan"
    user2.save

    user = CustomUser.find_by_first_name "Dmitrii"
    expect(user.id).to eq(user1.id)

    expect(CustomUser.find_by_last_name("Krassovkin")).to be_nil
    expect(CustomUser.find_all_by_first_name("Dmitrii").size).to eq(2)
  end

  # TODO
  it "should properly delete indices when record was deleted" do
    
  end
end
