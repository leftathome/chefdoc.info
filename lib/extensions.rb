require 'fileutils'
require 'open-uri'
require 'rubygems/package'

module YARD
  module Server
    class RubyDocServerSerializer < DocServerSerializer
      def initialize(command = nil)
        @asset_path = File.join('assets', command.library.to_s)
        super
        self.basepath = command.adapter.document_root
      end

      def serialized_path(object)
        if String === object
          File.join(@asset_path, object)
        else
          super(object)
        end
      end
    end

    class Commands::LibraryCommand
      def initialize(opts = {})
        super
        self.serializer = RubyDocServerSerializer.new(self)
      end
    end

    class LibraryVersion
      attr_accessor :platform

      protected

      def load_yardoc_from_disk_on_demand
        yfile = File.join(source_path, '.yardoc')
        if File.directory?(yfile)
          if File.exist?(File.join(yfile, 'complete'))
            self.yardoc_file = yfile
            return
          else
            raise LibraryNotPreparedError
          end
        end

        # Generate
        Thread.new do
          generate_yardoc
          self.yardoc_file = yfile
        end
        raise LibraryNotPreparedError
      end

      def load_yardoc_from_remote_gem
        yfile = File.join(source_path, '.yardoc')
        if File.directory?(yfile)
          if File.exist?(File.join(yfile, 'complete'))
            self.yardoc_file = yfile
            return
          else
            raise LibraryNotPreparedError
          end
        end

        # Remote gemfile from rubygems.org
        suffix = platform ? "-#{platform}" : ""
        url = "http://rubygems.org/downloads/#{to_s(false)}#{suffix}.gem"
        log.debug "Searching for remote gem file #{url}"
        Thread.new do
          begin
            open(url) do |io|
              expand_gem(io)
              generate_yardoc
              clean_source
            end
            self.yardoc_file = yfile
          rescue OpenURI::HTTPError
          rescue IOError
            self.yardoc_file = yfile
          end
        end
        raise LibraryNotPreparedError
      end

      def source_path_for_remote_gem
        File.join(::REMOTE_GEMS_PATH, name[0].downcase, name, version)
      end

      def source_path_for_disk_on_demand
        File.join(::STDLIB_PATH, version, name)
      end

      alias load_yardoc_from_github load_yardoc_from_disk

      def source_path_for_github
        File.join(::REPOS_PATH, name.split('/', 2).reverse.join('/'), version)
      end

      private

      def generate_yardoc
        `cd #{source_path} &&
          #{YARD::ROOT}/../bin/yardoc -n -q --safe &&
          touch .yardoc/complete`
      end

      def expand_gem(io)
        log.debug "Expanding remote gem #{to_s(false)} to #{source_path}..."
        FileUtils.mkdir_p(source_path)

        if Gem::VERSION >= '2.0.0'
          require 'rubygems/package/tar_reader'
          reader = Gem::Package::TarReader.new(io)
          reader.each do |pkg|
            if pkg.full_name == 'data.tar.gz'
              Zlib::GzipReader.wrap(pkg) do |gzio|
                tar = Gem::Package::TarReader.new(gzio)
                tar.each do |entry|
                  mode = entry.header.mode
                  file = File.join(source_path, entry.full_name)
                  FileUtils.mkdir_p(File.dirname(file))
                  File.open(file, 'wb') do |out|
                    out.write(entry.read)
                    out.fsync rescue nil
                  end
                end
              end
              break
            end
          end
        else
          Gem::Package.open(io) do |pkg|
            pkg.each do |entry|
              pkg.extract_entry(source_path, entry)
            end
          end
        end
      end

      def clean_source
        SourceCleaner.new(source_path).clean
      end
    end
  # Empty shell for now, we will extend here if necessary.
  class CookbookVersion < LibraryVersion
  end
  end

  module CLI
    class Yardoc
      def yardopts(file = options_file)
        list = IO.read(file).shell_split
        list.map {|a| %w(-c --use-cache --db -b --query).include?(a) ? '-o' : a }
      rescue Errno::ENOENT
        []
      end

      def support_rdoc_document_file!(file = '.document')
        IO.read(File.join(File.dirname(options_file), file)).gsub(/^[ \t]*#.+/m, '').split(/\s+/)
      rescue Errno::ENOENT
        []
      end

      def add_extra_files(*files)
        files.map! {|f| f.include?("*") ? Dir.glob(File.join(File.dirname(options_file), f)) : f }.flatten!
        files.each do |file|
          file = File.join(File.dirname(options_file), file) unless file[0] == '/'
          if File.file?(file)
            fname = file.gsub(File.dirname(options_file) + '/', '')
            options[:files] << CodeObjects::ExtraFileObject.new(fname)
          end
        end
      end
    end
  end
end
