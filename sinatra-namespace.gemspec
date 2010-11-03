Gem::Specification.new do |s|
  # Get the facts.
  s.name             = "sinatra-namespace"
  s.version          = "0.6.1"
  s.description      = "Adds namespaces to Sinatra, allows namespaces to have local helpers."

  # Dependencies
  s.add_dependency "sinatra", "~> 1.1"
  s.add_development_dependency "sinatra-test-helper", "~> 0.5.0"
  s.add_development_dependency "rspec", "~> 1.3.0"

  # Those should be about the same in any BigBand extension.
  s.authors          = ["Konstantin Haase"]
  s.email            = "konstantin.mailinglists@googlemail.com"
  s.files            = `git ls-files`.split("\n")
  s.has_rdoc         = 'yard'
  s.homepage         = "http://github.com/rkh/#{s.name}"
  s.require_paths    = ["lib"]
  s.summary          = s.description
end
