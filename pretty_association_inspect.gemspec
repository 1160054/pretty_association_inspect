# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pretty_association_inspect/version'

Gem::Specification.new do |spec|
  spec.name          = "pretty_association_inspect"
  spec.version       = PrettyAssociationInspect::VERSION
  spec.authors       = ["小野寺　優太"]
  spec.email         = ["s1160054@gmail.com"]

  spec.summary       = %q{モデルで定義されたメソッド、関連、バリデーションを、Railsコンソール上で美しく表示します。}
  spec.description   = %q{すべてのモデルに「to」というクラスメソッド及びインスタンスメソッドが追加されます。}
  spec.homepage      = "https://s1160054@bitbucket.org/s1160054/pretty_association_inspect.git"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  spec.metadata['allowed_push_host'] = "https://s1160054@bitbucket.org/s1160054/pretty_association_inspect.git"
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rails"
  spec.add_development_dependency "awesome_print"
end
