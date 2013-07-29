#!/bin/env ruby
require 'rubygems'
require 'chef/knife'
require 'chef/knife/cookbook_site_show'
require_relative '../init'

@ckcss = Chef::Knife::CookbookSiteShow.new()
class OpscodeCookbook
  attr_accessor :name, :version, :url

  def initialize(name, version, url)
    @name, @version, @url = name.to_s, version.to_s, url.to_s
    puts "Received: #{@name}, #{@version}, #{@url}"
  end

  def to_s
    "#{name}#{url ? ":"+url : ""} (#{version})" # + url ? " @ #{url}" : ""
  end
end

def get_cookbook_data(cb_name, cb_version=nil)
  
  if cb_version.nil?
    @ckcss.noauth_rest.get_rest("http://cookbooks.opscode.com/api/v1/cookbooks/#{cb_name}")
  else
    @ckcss.noauth_rest.get_rest("http://cookbooks.opscode.com/api/v1/cookbooks/#{cb_name}/versions/#{cb_version.gsub('.', '_')}")
  end
end

def pick_best_versions(versions)
  seen = {}
  uniqversions = []
  versions.each do |ver|
    uniqversions |= [ver.version]
    (seen[ver.version] ||= []).send(:unshift, ver)
  end
  puts "Seen: #{seen}"
  puts "Uniq: #{uniqversions}"
  # look, this doesn't have to be this hard.
  uniqversions
end

libs = {}
categories = []
#@ckcss.get_cookbook_list().each do |cookbook|
["1password","zlib"].each do |cookbook|
  cbd = get_cookbook_data(cookbook)
  puts cbd.inspect
  u = URI(cbd["external_url"].start_with?("http") ? cbd["external_url"] : "http://" + cbd["external_url"])
  # default to http if the url scheme's unqualified
  u.scheme = "http" if u.scheme.nil?
  puts u.to_s
  cbd["versions"].each do |version_url|
    v = version_url.split("/")[-1].gsub("_",".")
    (libs[cookbook] ||= []) << OpscodeCookbook.new(cookbook, v, u.to_s)
  end
  categories << cbd["category"]
end

categories.flatten!

puts "libs: #{libs.inspect}"

puts "categories: #{categories.flatten.inspect}"

# Keep track of updated cookbooks
changed_cookbooks = {}
File.readlines(REMOTE_CBS_FILE).each do |line|
  name, rest = line.split(/\s+/, 2)
  changed_cookbooks[name] = rest
end if File.exist?(REMOTE_CBS_FILE)

File.open(REMOTE_CBS_FILE, 'w') do |file|
  libs.each do |k, v|
    line = pick_best_versions(v).join(' ')
    changed_cookbooks.delete(k) if changed_cookbooks[k] && changed_cookbooks[k].strip == line.strip
    file.puts("#{k}:#{v.first.url} #{line}")
  end
end

# Clear cache for gem frames page with new gems
# TODO: improve this cache invalidation to be version specific
changed_cookbooks.keys.each do |gem|
  paths = [File.join(STATIC_PATH, 'cookbooks', gem), File.join(STATIC_PATH, 'list', 'cookbooks', gem)]
  paths.each do |path|
    system "rm -rf #{path}" if File.directory?(path)
  end
end

if changed_cookbooks.size > 0
  puts ">> Updated #{changed_cookbooks.size} gems:"
  puts changed_cookbooks.keys.join(', ')
end
