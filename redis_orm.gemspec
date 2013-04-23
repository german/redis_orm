# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{redis_orm}
  s.version = "0.6.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.authors = [%q{Dmitrii Samoilov}]
  s.date = %q{2012-05-23}
  s.description = %q{ORM for Redis (advanced key-value storage) with ActiveRecord API}
  s.email = %q{germaninthetown@gmail.com}
  s.extra_rdoc_files = [%q{CHANGELOG}, %q{LICENSE}, %q{README.md}, %q{TODO}, %q{lib/redis_orm.rb}, %q{lib/redis_orm/active_model_behavior.rb}, %q{lib/redis_orm/associations/belongs_to.rb}, %q{lib/redis_orm/associations/has_many.rb}, %q{lib/redis_orm/associations/has_many_helper.rb}, %q{lib/redis_orm/associations/has_many_proxy.rb}, %q{lib/redis_orm/associations/has_one.rb}, %q{lib/redis_orm/redis_orm.rb}, %q{lib/redis_orm/utils.rb}]
  s.files = [%q{CHANGELOG}, %q{Gemfile}, %q{LICENSE}, %q{Manifest}, %q{README.md}, %q{Rakefile}, %q{TODO}, %q{benchmarks/sortable_benchmark.rb}, %q{lib/redis_orm.rb}, %q{lib/redis_orm/active_model_behavior.rb}, %q{lib/redis_orm/associations/belongs_to.rb}, %q{lib/redis_orm/associations/has_many.rb}, %q{lib/redis_orm/associations/has_many_helper.rb}, %q{lib/redis_orm/associations/has_many_proxy.rb}, %q{lib/redis_orm/associations/has_one.rb}, %q{lib/redis_orm/redis_orm.rb}, %q{lib/redis_orm/utils.rb}, %q{redis_orm.gemspec}, %q{test/association_indices_test.rb}, %q{test/associations_test.rb}, %q{test/atomicity_test.rb}, %q{test/basic_functionality_test.rb}, %q{test/callbacks_test.rb}, %q{test/changes_array_test.rb}, %q{test/classes/album.rb}, %q{test/classes/article.rb}, %q{test/classes/book.rb}, %q{test/classes/catalog_item.rb}, %q{test/classes/category.rb}, %q{test/classes/city.rb}, %q{test/classes/comment.rb}, %q{test/classes/country.rb}, %q{test/classes/custom_user.rb}, %q{test/classes/cutout.rb}, %q{test/classes/cutout_aggregator.rb}, %q{test/classes/default_user.rb}, %q{test/classes/dynamic_finder_user.rb}, %q{test/classes/empty_person.rb}, %q{test/classes/giftcard.rb}, %q{test/classes/jigsaw.rb}, %q{test/classes/location.rb}, %q{test/classes/message.rb}, %q{test/classes/note.rb}, %q{test/classes/omni_user.rb}, %q{test/classes/person.rb}, %q{test/classes/photo.rb}, %q{test/classes/profile.rb}, %q{test/classes/sortable_user.rb}, %q{test/classes/timestamp.rb}, %q{test/classes/user.rb}, %q{test/classes/uuid_default_user.rb}, %q{test/classes/uuid_timestamp.rb}, %q{test/classes/uuid_user.rb}, %q{test/dynamic_finders_test.rb}, %q{test/exceptions_test.rb}, %q{test/has_one_has_many_test.rb}, %q{test/indices_test.rb}, %q{test/modules/belongs_to_model_within_module.rb}, %q{test/modules/has_many_model_within_module.rb}, %q{test/options_test.rb}, %q{test/polymorphic_test.rb}, %q{test/redis.conf}, %q{test/sortable_test.rb}, %q{test/test_helper.rb}, %q{test/uuid_as_id_test.rb}, %q{test/validations_test.rb}]
  s.homepage = %q{https://github.com/german/redis_orm}
  s.rdoc_options = [%q{--line-numbers}, %q{--inline-source}, %q{--title}, %q{Redis_orm}, %q{--main}, %q{README.md}]
  s.require_paths = [%q{lib}]
  s.rubyforge_project = %q{redis_orm}
  s.rubygems_version = %q{1.8.6}
  s.summary = %q{ORM for Redis (advanced key-value storage) with ActiveRecord API}
  s.test_files = [%q{test/atomicity_test.rb}, %q{test/indices_test.rb}, %q{test/sortable_test.rb}, %q{test/uuid_as_id_test.rb}, %q{test/test_helper.rb}, %q{test/options_test.rb}, %q{test/callbacks_test.rb}, %q{test/exceptions_test.rb}, %q{test/associations_test.rb}, %q{test/validations_test.rb}, %q{test/basic_functionality_test.rb}, %q{test/dynamic_finders_test.rb}, %q{test/changes_array_test.rb}, %q{test/polymorphic_test.rb}, %q{test/association_indices_test.rb}, %q{test/has_one_has_many_test.rb}]

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activesupport>, [">= 3.0.0"])
      s.add_runtime_dependency(%q<activemodel>, [">= 3.0.0"])
      s.add_runtime_dependency(%q<redis>, [">= 2.2.0"])
      s.add_runtime_dependency(%q<uuid>, [">= 2.3.2"])
      s.add_development_dependency(%q<rspec>, [">= 2.5.0"])
      s.add_development_dependency(%q<rspec-rails>, [">= 2.5.0"])
      s.add_development_dependency(%q<ammeter>)
      s.add_development_dependency(%q<rails>, [">= 3.0.0"])
    else
      s.add_dependency(%q<activesupport>, [">= 3.0.0"])
      s.add_dependency(%q<activemodel>, [">= 3.0.0"])
      s.add_dependency(%q<redis>, [">= 2.2.0"])
      s.add_dependency(%q<uuid>, [">= 2.3.2"])
      s.add_dependency(%q<rspec>, [">= 2.5.0"])
    end
  else
    s.add_dependency(%q<activesupport>, [">= 3.0.0"])
    s.add_dependency(%q<activemodel>, [">= 3.0.0"])
    s.add_dependency(%q<redis>, [">= 2.2.0"])
    s.add_dependency(%q<uuid>, [">= 2.3.2"])
    s.add_dependency(%q<rspec>, [">= 2.5.0"])
  end
end
