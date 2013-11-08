require File.dirname(File.expand_path(__FILE__)) + '/test_helper.rb'

describe "check polymorphic property" do
  it "should provide proper associations and save records correctly for has_one/belongs_to polymorphic" do
    book = Book.new :title => "Permutation City", :author => "Egan Greg", :price => 1529
    book.save

    giftcard = Giftcard.create :title => "Happy New Year!"

    ci1 = CatalogItem.create :title => giftcard.title
    ci1.resource = giftcard
    
    ci2 = CatalogItem.create :title => book.title
    ci2.resource = book
    
    CatalogItem.count.should == 2
    [ci1, ci2].collect{|ci| ci.title}.should == [giftcard.title, book.title]
    
    ci1.resource.title.should == giftcard.title
    ci2.resource.title.should == book.title
    
    Book.first.catalog_item.should be
    Book.first.catalog_item.id.should == ci2.id
    
    Giftcard.first.catalog_item.should be
    Giftcard.first.catalog_item.id.should == ci1.id
  end
  
  it "should provide proper associations and save records correctly for has_many/belongs_to polymorphic" do
    country = Country.create :name => "Ukraine"
    city = City.create :name => "Lviv"
    
    person = Person.create :name => "german"
    person.location = country
    
    Person.first.location.id.should == country.id
    City.first.people.count.should == 0
    Country.first.people.count.should == 1
    Country.first.people[0].id.should == person.id
    
    person = Person.first
    person.location = city
    
    Person.first.location.id.should == city.id
    City.first.people.count.should == 1
    City.first.people[0].id.should == person.id
    Country.first.people.count.should == 0
  end
  
  it "should delete records properly" do
    country = Country.create :name => "Ukraine"
    person = Person.create :name => "german"
    person.location = country
    
    Person.first.location.id.should == country.id
    Country.first.people.count.should == 1
    Country.first.people[0].id.should == person.id
    
    person.destroy
    Person.count.should == 0
    RedisOrm.redis.hgetall("user:#{person.id}").should == {}
    RedisOrm.redis.zrank("user:ids", person.id).should == nil
    Country.first.people.count.should == 0
  end
end
