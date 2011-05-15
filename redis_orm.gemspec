# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{redis_orm}
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.authors = ["Dmitrii Samoilov"]
  s.date = %q{2011-05-03}
  s.description = %q{almost ActiveRecord compatible ORM for Redis key-value storage}
  s.email = %q{germaninthetown@gmail.com}
  s.extra_rdoc_files = ["lib/redis_orm/redis_orm.rb"]
  s.files = ["Rakefile", "lib/redis_orm/redis_orm.rb", "Manifest", "redis_orm.gemspec"]
  s.homepage = %q{http://github.com/german/redis_orm}
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Redis_orm"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{redis_orm}
  s.rubygems_version = %q{1.6.2}
  s.summary = %q{almost ActiveRecord compatible ORM for Redis key-value storage}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activesupport>, [">= 0"])
    else
      s.add_dependency(%q<activesupport>, [">= 0"])
    end
  else
    s.add_dependency(%q<activesupport>, [">= 0"])
  end
end
