$:.unshift(File.expand_path(File.dirname(__FILE__)))
$:.unshift(File.expand_path(File.dirname(__FILE__) + '/lib'))
$:.unshift(File.expand_path(File.dirname(__FILE__) + '/yard/lib'))
$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../yard/lib'))

require 'rubygems'
require 'bundler/setup'
require 'yard'
require 'yard-sd'
require 'yard-rails'
require 'yard-kramdown'

YARD::Server::Adapter.setup
YARD::Templates::Engine.register_template_path(File.dirname(__FILE__) + '/templates')

def __p(*extra)
  file = extra.last == :file
  extra.pop if file
  path = File.join(File.dirname(__FILE__), *extra)
  FileUtils.mkdir_p(path) unless File.exists?(path) || file
  path
end

CONFIG_PATH      = __p('config')
STATIC_PATH      = __p('public')
REPOS_PATH       = __p('repos/github')
REMOTE_GEMS_PATH = __p('repos/gems')
REMOTE_CBS_PATH = __p('repos/cookbooks')
STDLIB_PATH      = __p('repos/stdlib')
FEATURED_PATH    = __p('repos/featured')
TMP_PATH         = __p('tmp')
DATA_PATH        = __p('data')
TEMPLATES_PATH   = __p('templates')
CONFIG_FILE      = __p('config.yaml', :file)
REMOTE_CBS_FILE = __p('data', 'remote_cookbooks', :file)
RECENT_SQL_FILE  = __p('data', 'recent.sqlite', :file)
