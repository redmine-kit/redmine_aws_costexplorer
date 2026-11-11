# frozen_string_literal: true

# The plugin as a gem, published to GitHub Packages (.github/workflows/gem.yml).
# The gem holds the plugin's run-time files, so that the installed gem can be
# linked into Redmine's plugins/ (docs/setup.md#installation). The plugin's
# Gemfile is not in it: Redmine's Gemfile would load it again.
Gem::Specification.new do |spec|
  spec.name = 'redmine_aws_costexplorer'
  spec.version = File.read(File.join(__dir__, 'lib/redmine_aws/costexplorer.rb'))[/VERSION = '([^']+)'/, 1]
  spec.summary = "Shows the AWS account's costs from Cost Explorer in Redmine's administration"
  spec.authors = ['Redmine Kit']
  spec.license = 'GPL-2.0-or-later'
  spec.homepage = 'https://github.com/redmine-kit/redmine_aws_costexplorer'
  spec.required_ruby_version = '>= 4.0'
  spec.files = Dir['{init.rb,LICENSE}', '{app,assets,config,db,lib,help}/**/*']
  spec.add_dependency 'aws-sdk-costexplorer', '~> 1.160'
  spec.add_dependency 'redmine_aws', '~> 0.1'
  spec.metadata['github_repo'] = 'ssh://github.com/redmine-kit/redmine_aws_costexplorer'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
