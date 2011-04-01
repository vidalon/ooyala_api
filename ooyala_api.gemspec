# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{ooyala_api}
  s.version = "0.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.authors = ["Ooyala"]
  s.date = %q{2011-04-01}
  s.description = %q{Ooyala REST API client classes.}
  s.email = %q{support@ooyala.com}
  s.extra_rdoc_files = ["README.rdoc", "lib/ooyala_api.rb"]
  s.files = ["README.rdoc", "Rakefile", "lib/ooyala_api.rb", "Manifest", "ooyala_api.gemspec"]
  s.homepage = %q{http://github.com/vidalon/ooyala_api}
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Ooyala_api", "--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{ooyala_api}
  s.rubygems_version = %q{1.6.2}
  s.summary = %q{Ooyala REST API client classes.}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
